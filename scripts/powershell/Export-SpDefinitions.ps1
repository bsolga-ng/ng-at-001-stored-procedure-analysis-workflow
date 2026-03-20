<#
.SYNOPSIS
    Export stored procedure definitions from SQL Server to individual .sql files.

.DESCRIPTION
    Connects to a SQL Server instance and exports CREATE PROCEDURE scripts for all
    (or filtered) stored procedures. Each SP is saved as a separate .sql file.
    This bridges the gap between the database and Claude Code, which operates on files.

.PARAMETER ServerInstance
    SQL Server instance name (e.g., "localhost", "server\instance", "server.database.windows.net")

.PARAMETER Database
    Database name

.PARAMETER SpName
    Optional: Export a single SP by name (supports wildcards: "DataSync.*")

.PARAMETER Schema
    Optional: Filter by schema (default: all schemas)

.PARAMETER OutputDir
    Output directory for .sql files (default: docs/sp-definitions)

.PARAMETER Credential
    Optional: SQL Server credential. If omitted, uses Windows/Integrated auth.

.PARAMETER UseAzureAD
    Switch: Use Azure AD Interactive authentication (for Azure SQL)

.EXAMPLE
    # Export all SPs
    .\Export-SpDefinitions.ps1 -ServerInstance "localhost" -Database "AttractDB"

    # Export single SP
    .\Export-SpDefinitions.ps1 -ServerInstance "localhost" -Database "AttractDB" -SpName "DataSync.GetJobsForSync"

    # Export by schema
    .\Export-SpDefinitions.ps1 -ServerInstance "localhost" -Database "AttractDB" -Schema "DataSync"

    # Azure SQL with credential
    $cred = Get-Credential
    .\Export-SpDefinitions.ps1 -ServerInstance "server.database.windows.net" -Database "AttractDB" -Credential $cred

    # Azure SQL with AAD
    .\Export-SpDefinitions.ps1 -ServerInstance "server.database.windows.net" -Database "AttractDB" -UseAzureAD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [Parameter(Mandatory)]
    [string]$Database,

    [string]$SpName = "",

    [string]$Schema = "",

    [string]$OutputDir = "docs/sp-definitions",

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

function New-SqlCommand {
    param([string]$Text, $Connection)
    if ($useMds) {
        $cmd = [Microsoft.Data.SqlClient.SqlCommand]::new($Text, $Connection)
    } else {
        $cmd = [System.Data.SqlClient.SqlCommand]::new($Text, $Connection)
    }
    $cmd.CommandTimeout = 120
    return $cmd
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

# Build parameterized query
$query = @"
SELECT
    s.name AS [Schema],
    p.name AS [Name],
    OBJECT_DEFINITION(p.object_id) AS [Definition],
    p.create_date AS [Created],
    p.modify_date AS [Modified],
    (SELECT COUNT(*) FROM sys.parameters WHERE object_id = p.object_id) AS [ParamCount]
FROM sys.procedures p
JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE 1=1
"@

$sqlParams = @{}

if ($SpName) {
    if ($SpName -match '\.') {
        $parts = $SpName -split '\.'
        $query += "`n    AND s.name = @SchemaFilter AND p.name LIKE @NameFilter"
        $sqlParams["@SchemaFilter"] = $parts[0]
        $sqlParams["@NameFilter"] = $parts[1].Replace('*', '%')
    } else {
        $query += "`n    AND p.name LIKE @NameFilter"
        $sqlParams["@NameFilter"] = $SpName.Replace('*', '%')
    }
}

if ($Schema) {
    $query += "`n    AND s.name = @SchemaParam"
    $sqlParams["@SchemaParam"] = $Schema
}

$query += "`nORDER BY s.name, p.name"

# Create output directory
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Connect and export
$connection = New-SqlConnection -ConnString $connString
$connection.Open()

try {
    $command = New-SqlCommand -Text $query -Connection $connection
    foreach ($p in $sqlParams.GetEnumerator()) {
        $command.Parameters.AddWithValue($p.Key, $p.Value) | Out-Null
    }
    $reader = $command.ExecuteReader()

    $count = 0
    $manifest = @()

    while ($reader.Read()) {
        $schemaVal = $reader["Schema"]
        $name = $reader["Name"]
        $definition = $reader["Definition"]
        $created = $reader["Created"]
        $modified = $reader["Modified"]
        $paramCount = $reader["ParamCount"]

        # Create schema subdirectory
        $schemaDir = Join-Path $OutputDir $schemaVal
        New-Item -ItemType Directory -Path $schemaDir -Force | Out-Null

        # Write SP definition
        $filePath = Join-Path $schemaDir "$name.sql"
        $definition | Out-File -FilePath $filePath -Encoding utf8

        $manifest += [PSCustomObject]@{
            Schema    = $schemaVal
            Name      = $name
            File      = $filePath
            Created   = $created
            Modified  = $modified
            ParamCount = $paramCount
            Lines     = ($definition -split "`n").Count
        }

        $count++
        Write-Host "  Exported: $schemaVal.$name ($paramCount params, $(($definition -split "`n").Count) lines)" -ForegroundColor Green
    }

    $reader.Close()

    # Write manifest
    $manifestPath = Join-Path $OutputDir "manifest.json"
    $manifest | ConvertTo-Json -Depth 3 | Out-File -FilePath $manifestPath -Encoding utf8

    Write-Host "`n--- Export Complete ---" -ForegroundColor Cyan
    Write-Host "Total SPs exported: $count"
    Write-Host "Output directory: $OutputDir"
    Write-Host "Manifest: $manifestPath"
    Write-Host "`nNext step: Run /sp-discover in Claude Code to build the registry"

} finally {
    $connection.Close()
}
