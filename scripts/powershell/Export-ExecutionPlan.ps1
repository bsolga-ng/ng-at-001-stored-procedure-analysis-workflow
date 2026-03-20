<#
.SYNOPSIS
    Capture the estimated execution plan for a stored procedure invocation.

.DESCRIPTION
    Uses SET SHOWPLAN_XML ON to capture the estimated execution plan for a given SP
    with specified parameters. Outputs both XML (for SSMS import) and a simplified
    text summary that Claude Code can analyze.

    Note: Requires SHOWPLAN permission on the database.

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

.PARAMETER UseAzureAD
    Switch: Use Azure AD Interactive authentication (for Azure SQL)

.PARAMETER TestConnection
    Switch: Only test the database connection and exit. Use to verify Azure AD auth works.

.EXAMPLE
    $params = @{ JobId = 123; SyncType = 'Full' }
    .\Export-ExecutionPlan.ps1 -ServerInstance "localhost" -Database "AttractDB" `
        -SpName "DataSync.GetJobsForSync" -Parameters $params

    # Test Azure AD connection
    .\Export-ExecutionPlan.ps1 -ServerInstance "server.database.windows.net" -Database "AttractDB" `
        -SpName "dbo.AnySpName" -UseAzureAD -TestConnection
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

    [PSCredential]$Credential,

    [switch]$UseAzureAD,

    [switch]$TestConnection
)

$ErrorActionPreference = "Stop"

# Prefer Microsoft.Data.SqlClient; fall back to System.Data.SqlClient
$useMds = $false
try {
    Import-Module SqlServer -ErrorAction SilentlyContinue
    [void][Microsoft.Data.SqlClient.SqlConnection]
    $useMds = $true
} catch {
    try {
        [void][System.Data.SqlClient.SqlConnection]
    } catch {
        Write-Error "No SQL client library found. Install the SqlServer module: Install-Module SqlServer -Scope CurrentUser"
        return
    }
}

function New-SqlConnection {
    param([string]$ConnString)
    if ($useMds) { return [Microsoft.Data.SqlClient.SqlConnection]::new($ConnString) }
    else { return [System.Data.SqlClient.SqlConnection]::new($ConnString) }
}

# Build connection string
$connParts = @(
    "Data Source=$ServerInstance",
    "Initial Catalog=$Database"
)

if ($UseAzureAD) {
    if ($useMds) {
        $connParts += "Authentication=Active Directory Interactive"
        $connParts += "Encrypt=True"
    } else {
        Write-Error "Azure AD auth requires Microsoft.Data.SqlClient. Install the SqlServer module: Install-Module SqlServer -Scope CurrentUser"
        return
    }
} elseif ($Credential) {
    $connParts += "User ID=$($Credential.UserName)"
    $connParts += "Password=$($Credential.GetNetworkCredential().Password)"
    if ($ServerInstance -match '\.database\.windows\.net') { $connParts += "Encrypt=True" }
} else {
    $connParts += "Integrated Security=True"
}

$connString = $connParts -join ";"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Validate SP name to prevent SQL injection — only allow schema.name with alphanumeric, underscores, dots
if ($SpName -notmatch '^[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)?$') {
    Write-Error "Invalid SP name: '$SpName'. Expected format: 'Schema.Name' or 'Name' with only alphanumeric characters and underscores."
    return
}

$connection = New-SqlConnection -ConnString $connString
$connection.Open()

# Test connection mode — verify auth works and exit
if ($TestConnection) {
    if ($useMds) {
        $testCmd = [Microsoft.Data.SqlClient.SqlCommand]::new("SELECT DB_NAME() AS [Database], SUSER_SNAME() AS [User], @@VERSION AS [Version]", $connection)
    } else {
        $testCmd = [System.Data.SqlClient.SqlCommand]::new("SELECT DB_NAME() AS [Database], SUSER_SNAME() AS [User], @@VERSION AS [Version]", $connection)
    }
    $reader = $testCmd.ExecuteReader()
    if ($reader.Read()) {
        Write-Host "--- Connection Test PASSED ---" -ForegroundColor Green
        Write-Host "Database: $($reader['Database'])"
        Write-Host "User:     $($reader['User'])"
        Write-Host "Server:   $($reader['Version'].Substring(0, [Math]::Min(80, $reader['Version'].Length)))..."
        Write-Host "Auth:     $(if ($UseAzureAD) { 'Azure AD' } elseif ($Credential) { 'SQL Auth' } else { 'Windows Integrated' })"
        Write-Host "`nSHOWPLAN permission check..."
    }
    $reader.Close()

    # Test SHOWPLAN permission
    try {
        if ($useMds) {
            $showplanTest = [Microsoft.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML ON", $connection)
        } else {
            $showplanTest = [System.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML ON", $connection)
        }
        $showplanTest.ExecuteNonQuery() | Out-Null
        Write-Host "SHOWPLAN permission: GRANTED" -ForegroundColor Green

        if ($useMds) {
            $offCmd = [Microsoft.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML OFF", $connection)
        } else {
            $offCmd = [System.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML OFF", $connection)
        }
        $offCmd.ExecuteNonQuery() | Out-Null
    } catch {
        Write-Host "SHOWPLAN permission: DENIED — $($_.Exception.Message)" -ForegroundColor Red
    }

    $connection.Close()
    return
}

try {
    # Enable showplan
    if ($useMds) {
        $enableCmd = [Microsoft.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML ON", $connection)
    } else {
        $enableCmd = [System.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML ON", $connection)
    }
    $enableCmd.ExecuteNonQuery() | Out-Null

    # Build safe SP call using QUOTENAME for schema and name parts
    # Note: SHOWPLAN_XML requires a text command with EXEC — it cannot use CommandType.StoredProcedure
    if ($SpName -match '\.') {
        $schemaPart, $namePart = $SpName -split '\.'
        $safeExec = "EXEC [$schemaPart].[$namePart]"
    } else {
        $safeExec = "EXEC [$SpName]"
    }

    $spParams = @{}

    if ($Parameters.Count -gt 0) {
        $paramAssignments = @()
        foreach ($p in $Parameters.GetEnumerator()) {
            $paramName = "@$($p.Key)"
            $paramAssignments += "$paramName = $paramName"
            $spParams[$paramName] = $p.Value
        }
        $safeExec = $safeExec + " " + ($paramAssignments -join ", ")
    }

    if ($useMds) {
        $planCmd = [Microsoft.Data.SqlClient.SqlCommand]::new($safeExec, $connection)
    } else {
        $planCmd = [System.Data.SqlClient.SqlCommand]::new($safeExec, $connection)
    }
    $planCmd.CommandTimeout = 120

    foreach ($p in $spParams.GetEnumerator()) {
        $planCmd.Parameters.AddWithValue($p.Key, $p.Value) | Out-Null
    }

    $reader = $planCmd.ExecuteReader()

    $planXml = ""
    if ($reader.Read()) {
        $planXml = $reader.GetString(0)
    }
    $reader.Close()

    # Disable showplan
    if ($useMds) {
        $disableCmd = [Microsoft.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML OFF", $connection)
    } else {
        $disableCmd = [System.Data.SqlClient.SqlCommand]::new("SET SHOWPLAN_XML OFF", $connection)
    }
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
        $paramDesc = ($spParams.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join ", "
        $summaryLines += "# Parameters: $paramDesc"
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
                $idxSchema = $idx.GetAttribute("Schema")
                $summaryLines += "- Table: $idxSchema.$table"

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
        Write-Warning "Note: SHOWPLAN requires the SHOWPLAN permission on the database."
    }

} finally {
    $connection.Close()
}
