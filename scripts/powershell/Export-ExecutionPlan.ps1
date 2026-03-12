<#
.SYNOPSIS
    Capture the estimated execution plan for a stored procedure invocation.

.DESCRIPTION
    Runs SET SHOWPLAN_XML ON to capture the estimated execution plan for a given SP
    with specified parameters. Outputs both XML (for SSMS import) and a simplified
    text summary that Claude Code can analyze.

.PARAMETER ServerInstance
    SQL Server instance name

.PARAMETER Database
    Database name

.PARAMETER SpName
    Stored procedure name (schema-qualified)

.PARAMETER Parameters
    Hashtable of parameter names and values

.PARAMETER OutputDir
    Output directory (default: docs/sp-analysis/execution-plans)

.PARAMETER Credential
    Optional: SQL auth credential

.EXAMPLE
    $params = @{ JobId = 123; SyncType = 'Full' }
    .\Export-ExecutionPlan.ps1 -ServerInstance "localhost" -Database "AttractDB" `
        -SpName "DataSync.GetJobsForSync" -Parameters $params
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [Parameter(Mandatory)]
    [string]$Database,

    [Parameter(Mandatory)]
    [string]$SpName,

    [hashtable]$Parameters = @{},

    [string]$OutputDir = "docs/sp-analysis/execution-plans",

    [PSCredential]$Credential
)

$ErrorActionPreference = "Stop"

$connStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$connStringBuilder["Data Source"] = $ServerInstance
$connStringBuilder["Initial Catalog"] = $Database

if ($Credential) {
    $connStringBuilder["User ID"] = $Credential.UserName
    $connStringBuilder["Password"] = $Credential.GetNetworkCredential().Password
} else {
    $connStringBuilder["Integrated Security"] = $true
}

$connString = $connStringBuilder.ToString()
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$connection = New-Object System.Data.SqlClient.SqlConnection($connString)
$connection.Open()

try {
    # Enable showplan
    $enableCmd = $connection.CreateCommand()
    $enableCmd.CommandText = "SET SHOWPLAN_XML ON"
    $enableCmd.ExecuteNonQuery() | Out-Null

    # Build EXEC statement
    $paramStr = ($Parameters.GetEnumerator() | ForEach-Object {
        $val = if ($_.Value -is [string]) { "'$($_.Value)'" } else { $_.Value }
        "@$($_.Key) = $val"
    }) -join ", "

    $execSql = if ($paramStr) { "EXEC $SpName $paramStr" } else { "EXEC $SpName" }

    $planCmd = $connection.CreateCommand()
    $planCmd.CommandText = $execSql
    $planCmd.CommandTimeout = 120
    $reader = $planCmd.ExecuteReader()

    $planXml = ""
    if ($reader.Read()) {
        $planXml = $reader.GetString(0)
    }
    $reader.Close()

    # Disable showplan
    $disableCmd = $connection.CreateCommand()
    $disableCmd.CommandText = "SET SHOWPLAN_XML OFF"
    $disableCmd.ExecuteNonQuery() | Out-Null

    if ($planXml) {
        # Save XML plan
        $safeName = $SpName -replace '\.', '_'
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $xmlPath = Join-Path $OutputDir "${safeName}_${timestamp}.sqlplan"
        $planXml | Out-File -FilePath $xmlPath -Encoding utf8

        # Parse and create text summary
        [xml]$planDoc = $planXml
        $ns = New-Object System.Xml.XmlNamespaceManager($planDoc.NameTable)
        $ns.AddNamespace("sp", "http://schemas.microsoft.com/sqlserver/2004/07/showplan")

        $summaryLines = @()
        $summaryLines += "# Execution Plan Summary: $SpName"
        $summaryLines += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $summaryLines += "# Parameters: $paramStr"
        $summaryLines += ""

        # Extract statement cost
        $statements = $planDoc.SelectNodes("//sp:StmtSimple", $ns)
        foreach ($stmt in $statements) {
            $stmtText = $stmt.GetAttribute("StatementText")
            $subtreeCost = $stmt.GetAttribute("StatementSubTreeCost")
            $estRows = $stmt.GetAttribute("StatementEstRows")

            if ($stmtText -and $subtreeCost) {
                $summaryLines += "## Statement"
                $summaryLines += "- SQL: $($stmtText.Substring(0, [Math]::Min(200, $stmtText.Length)))..."
                $summaryLines += "- Estimated cost: $subtreeCost"
                $summaryLines += "- Estimated rows: $estRows"
                $summaryLines += ""
            }
        }

        # Extract missing indexes
        $missingIndexes = $planDoc.SelectNodes("//sp:MissingIndex", $ns)
        if ($missingIndexes.Count -gt 0) {
            $summaryLines += "## Missing Indexes (SQL Server Recommendations)"
            foreach ($idx in $missingIndexes) {
                $table = $idx.GetAttribute("Table")
                $schema = $idx.GetAttribute("Schema")
                $summaryLines += "- Table: $schema.$table"

                $colGroups = $idx.SelectNodes("sp:ColumnGroup", $ns)
                foreach ($cg in $colGroups) {
                    $usage = $cg.GetAttribute("Usage")
                    $cols = ($cg.SelectNodes("sp:Column", $ns) | ForEach-Object { $_.GetAttribute("Name") }) -join ", "
                    $summaryLines += "  - $usage columns: $cols"
                }
            }
            $summaryLines += ""
        }

        # Extract warnings
        $warnings = $planDoc.SelectNodes("//sp:Warnings", $ns)
        if ($warnings.Count -gt 0) {
            $summaryLines += "## Warnings"
            foreach ($warn in $warnings) {
                $summaryLines += "- $($warn.InnerXml)"
            }
            $summaryLines += ""
        }

        $summaryPath = Join-Path $OutputDir "${safeName}_${timestamp}_summary.md"
        $summaryLines -join "`n" | Out-File -FilePath $summaryPath -Encoding utf8

        Write-Host "--- Execution Plan Exported ---" -ForegroundColor Cyan
        Write-Host "XML plan: $xmlPath"
        Write-Host "Summary:  $summaryPath"
        Write-Host "`nOpen XML in SSMS for visual plan. Feed summary to Claude Code for analysis."
    } else {
        Write-Warning "No execution plan returned. Check SP name and parameters."
    }

} finally {
    $connection.Close()
}
