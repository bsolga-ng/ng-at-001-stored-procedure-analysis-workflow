<#
.SYNOPSIS
    Export runtime statistics for stored procedures from SQL Server DMVs.

.DESCRIPTION
    Queries sys.dm_exec_procedure_stats to extract execution counts, average duration,
    last execution time, and resource usage. Provides a prioritized list of SPs
    for optimization based on actual runtime data.

.PARAMETER ServerInstance
    SQL Server instance name

.PARAMETER Database
    Database name

.PARAMETER TopN
    Number of top SPs to return (default: 50, ordered by total elapsed time)

.PARAMETER OutputDir
    Output directory (default: docs/sp-metadata)

.PARAMETER Credential
    Optional: SQL auth credential

.PARAMETER UseAzureAD
    Switch: Use Azure AD Interactive authentication (for Azure SQL)

.EXAMPLE
    .\Get-SpStats.ps1 -ServerInstance "localhost" -Database "AttractDB"
    .\Get-SpStats.ps1 -ServerInstance "localhost" -Database "AttractDB" -TopN 20
    .\Get-SpStats.ps1 -ServerInstance "server.database.windows.net" -Database "AttractDB" -UseAzureAD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [Parameter(Mandatory)]
    [string]$Database,

    [int]$TopN = 50,

    [string]$OutputDir = "docs/sp-metadata",

    [PSCredential]$Credential,

    [switch]$UseAzureAD
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

# Parameterized query — TopN is [int] typed so safe to interpolate, but Database uses a param
$query = @"
SELECT TOP (@TopN)
    DB_NAME(ps.database_id) AS [Database],
    SCHEMA_NAME(o.schema_id) AS [Schema],
    o.name AS [SPName],
    ps.execution_count AS [ExecutionCount],
    ps.total_elapsed_time / 1000 AS [TotalElapsedMs],
    ps.total_elapsed_time / NULLIF(ps.execution_count, 0) / 1000 AS [AvgElapsedMs],
    ps.min_elapsed_time / 1000 AS [MinElapsedMs],
    ps.max_elapsed_time / 1000 AS [MaxElapsedMs],
    ps.total_logical_reads AS [TotalLogicalReads],
    ps.total_logical_reads / NULLIF(ps.execution_count, 0) AS [AvgLogicalReads],
    ps.total_physical_reads AS [TotalPhysicalReads],
    ps.total_worker_time / 1000 AS [TotalCpuMs],
    ps.total_worker_time / NULLIF(ps.execution_count, 0) / 1000 AS [AvgCpuMs],
    ps.last_execution_time AS [LastExecution],
    ps.cached_time AS [CachedSince]
FROM sys.dm_exec_procedure_stats ps
JOIN sys.objects o ON ps.object_id = o.object_id
WHERE ps.database_id = DB_ID(@DatabaseName)
ORDER BY ps.total_elapsed_time DESC
"@

$conn = New-SqlConnection -ConnString $connString
$conn.Open()
try {
    if ($useMds) {
        $cmd = [Microsoft.Data.SqlClient.SqlCommand]::new($query, $conn)
        $adapter = [Microsoft.Data.SqlClient.SqlDataAdapter]::new($cmd)
    } else {
        $cmd = [System.Data.SqlClient.SqlCommand]::new($query, $conn)
        $adapter = [System.Data.SqlClient.SqlDataAdapter]::new($cmd)
    }
    $cmd.CommandTimeout = 120
    $cmd.Parameters.AddWithValue("@TopN", $TopN) | Out-Null
    $cmd.Parameters.AddWithValue("@DatabaseName", $Database) | Out-Null

    $table = New-Object System.Data.DataTable
    $adapter.Fill($table) | Out-Null

    # Save as JSON
    $stats = @($table.Rows | ForEach-Object {
        [PSCustomObject]@{
            Schema         = $_.Schema
            SPName         = $_.SPName
            ExecutionCount = $_.ExecutionCount
            TotalElapsedMs = $_.TotalElapsedMs
            AvgElapsedMs   = $_.AvgElapsedMs
            MinElapsedMs   = $_.MinElapsedMs
            MaxElapsedMs   = $_.MaxElapsedMs
            AvgLogicalReads = $_.AvgLogicalReads
            AvgCpuMs       = $_.AvgCpuMs
            LastExecution  = $_.LastExecution
        }
    })

    $jsonPath = Join-Path $OutputDir "sp-runtime-stats.json"
    $stats | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonPath -Encoding utf8

    # Save as Markdown table for easy reading
    $mdLines = @()
    $mdLines += "# SP Runtime Statistics"
    $mdLines += ""
    $mdLines += "> Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $mdLines += "> Source: $ServerInstance / $Database"
    $mdLines += "> Top $TopN by total elapsed time (since plan cache)"
    $mdLines += ""
    $mdLines += "| # | SP Name | Executions | Avg (ms) | Max (ms) | Avg Reads | Avg CPU (ms) | Last Run |"
    $mdLines += "|---|---------|-----------|---------|---------|-----------|-------------|----------|"

    $i = 1
    foreach ($s in $stats) {
        $mdLines += "| $i | $($s.Schema).$($s.SPName) | $($s.ExecutionCount) | $($s.AvgElapsedMs) | $($s.MaxElapsedMs) | $($s.AvgLogicalReads) | $($s.AvgCpuMs) | $($s.LastExecution) |"
        $i++
    }

    $mdPath = Join-Path $OutputDir "sp-runtime-stats.md"
    $mdLines -join "`n" | Out-File -FilePath $mdPath -Encoding utf8

    Write-Host "--- Runtime Stats Exported ---" -ForegroundColor Cyan
    Write-Host "SPs found: $($stats.Count)"
    Write-Host "JSON: $jsonPath"
    Write-Host "Markdown: $mdPath"
    Write-Host "`nTop 5 by total elapsed time:"
    $stats | Select-Object -First 5 | Format-Table SPName, ExecutionCount, AvgElapsedMs, MaxElapsedMs -AutoSize

} finally {
    $conn.Close()
}
