<#
.SYNOPSIS
    Export stored procedure metadata — parameters, dependencies, and referenced tables.

.DESCRIPTION
    Extracts structured metadata for stored procedures that Claude Code can use
    for deeper analysis without database access. Exports:
    - Parameter definitions (name, type, direction, defaults)
    - Table/view dependencies (from sys.sql_expression_dependencies)
    - Cross-SP dependencies
    - Index information for referenced tables

.PARAMETER ServerInstance
    SQL Server instance name

.PARAMETER Database
    Database name

.PARAMETER SpName
    Optional: Single SP name or wildcard pattern

.PARAMETER OutputDir
    Output directory (default: docs/sp-metadata)

.PARAMETER Credential
    Optional: SQL auth credential

.EXAMPLE
    .\Export-SpMetadata.ps1 -ServerInstance "localhost" -Database "AttractDB"
    .\Export-SpMetadata.ps1 -ServerInstance "localhost" -Database "AttractDB" -SpName "DataSync.GetJobsForSync"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [Parameter(Mandatory)]
    [string]$Database,

    [string]$SpName = "",

    [string]$OutputDir = "docs/sp-metadata",

    [PSCredential]$Credential
)

$ErrorActionPreference = "Stop"

# Build connection string
$connStringBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$connStringBuilder["Data Source"] = $ServerInstance
$connStringBuilder["Initial Catalog"] = $Database

if ($Credential) {
    $connStringBuilder["User ID"] = $Credential.UserName
    $connStringBuilder["Password"] = $Credential.GetNetworkCredential().Password
} else {
    $connStringBuilder["Integrated Security"] = $true
}

function Invoke-Query {
    param([string]$Query, [string]$ConnString)
    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnString)
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query
        $cmd.CommandTimeout = 120
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $table = New-Object System.Data.DataTable
        $adapter.Fill($table) | Out-Null
        return $table
    } finally {
        $conn.Close()
    }
}

$connString = $connStringBuilder.ToString()
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Get SP list
$spFilter = ""
if ($SpName) {
    if ($SpName -match '\.') {
        $parts = $SpName -split '\.'
        $spFilter = "AND s.name = '$($parts[0])' AND p.name LIKE '$($parts[1].Replace('*','%'))'"
    } else {
        $spFilter = "AND p.name LIKE '$($SpName.Replace('*','%'))'"
    }
}

$spList = Invoke-Query -ConnString $connString -Query @"
SELECT s.name AS [Schema], p.name AS [Name], p.object_id
FROM sys.procedures p
JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE 1=1 $spFilter
ORDER BY s.name, p.name
"@

$allMetadata = @()

foreach ($sp in $spList.Rows) {
    $schema = $sp.Schema
    $name = $sp.Name
    $objectId = $sp.object_id
    Write-Host "Processing: $schema.$name" -ForegroundColor Yellow

    # Parameters
    $params = Invoke-Query -ConnString $connString -Query @"
SELECT
    par.name AS [Name],
    TYPE_NAME(par.user_type_id) AS [Type],
    par.max_length AS [MaxLength],
    par.precision AS [Precision],
    par.scale AS [Scale],
    CASE WHEN par.is_output = 1 THEN 'OUT' ELSE 'IN' END AS [Direction],
    par.has_default_value AS [HasDefault],
    par.default_value AS [DefaultValue]
FROM sys.parameters par
WHERE par.object_id = $objectId
ORDER BY par.parameter_id
"@

    # Table/View dependencies
    $dependencies = Invoke-Query -ConnString $connString -Query @"
SELECT DISTINCT
    COALESCE(d.referenced_schema_name, 'dbo') AS [Schema],
    d.referenced_entity_name AS [Name],
    o.type_desc AS [Type]
FROM sys.sql_expression_dependencies d
LEFT JOIN sys.objects o ON o.name = d.referenced_entity_name
    AND o.schema_id = SCHEMA_ID(COALESCE(d.referenced_schema_name, 'dbo'))
WHERE d.referencing_id = $objectId
    AND d.referenced_entity_name IS NOT NULL
ORDER BY d.referenced_entity_name
"@

    # Cross-SP dependencies (SPs that call this SP)
    $callers = Invoke-Query -ConnString $connString -Query @"
SELECT DISTINCT
    SCHEMA_NAME(o.schema_id) AS [CallerSchema],
    o.name AS [CallerName],
    o.type_desc AS [CallerType]
FROM sys.sql_expression_dependencies d
JOIN sys.objects o ON o.object_id = d.referencing_id
WHERE d.referenced_entity_name = '$name'
    AND COALESCE(d.referenced_schema_name, 'dbo') = '$schema'
    AND o.object_id != $objectId
ORDER BY o.name
"@

    # Index info for referenced tables
    $tableNames = ($dependencies.Rows | Where-Object { $_.Type -match 'TABLE' } | ForEach-Object { "'$($_.Name)'" }) -join ','
    $indexes = @()
    if ($tableNames) {
        $indexes = Invoke-Query -ConnString $connString -Query @"
SELECT
    OBJECT_NAME(i.object_id) AS [Table],
    i.name AS [IndexName],
    i.type_desc AS [IndexType],
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS [Columns]
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) IN ($tableNames)
    AND i.name IS NOT NULL
GROUP BY i.object_id, i.name, i.type_desc
ORDER BY OBJECT_NAME(i.object_id), i.name
"@
    }

    $spMetadata = [PSCustomObject]@{
        Schema       = $schema
        Name         = $name
        Parameters   = @($params.Rows | ForEach-Object {
            [PSCustomObject]@{
                Name      = $_.Name
                Type      = $_.Type
                MaxLength = $_.MaxLength
                Direction = $_.Direction
                HasDefault = $_.HasDefault
                Default    = $_.DefaultValue
            }
        })
        Dependencies = @($dependencies.Rows | ForEach-Object {
            [PSCustomObject]@{
                Schema = $_.Schema
                Name   = $_.Name
                Type   = if ($_.Type) { $_.Type } else { "UNKNOWN" }
            }
        })
        CalledBy     = @($callers.Rows | ForEach-Object {
            [PSCustomObject]@{
                Schema = $_.CallerSchema
                Name   = $_.CallerName
                Type   = $_.CallerType
            }
        })
        Indexes      = @($indexes.Rows | ForEach-Object {
            [PSCustomObject]@{
                Table     = $_.Table
                IndexName = $_.IndexName
                Type      = $_.IndexType
                Columns   = $_.Columns
            }
        })
    }

    $allMetadata += $spMetadata
    Write-Host "  Params: $($params.Rows.Count) | Deps: $($dependencies.Rows.Count) | CalledBy: $($callers.Rows.Count)" -ForegroundColor Green
}

# Write combined metadata
$outputPath = Join-Path $OutputDir "sp-metadata.json"
$allMetadata | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputPath -Encoding utf8

Write-Host "`n--- Metadata Export Complete ---" -ForegroundColor Cyan
Write-Host "SPs processed: $($allMetadata.Count)"
Write-Host "Output: $outputPath"
Write-Host "`nNext step: Run /sp-analyze in Claude Code — it will use this metadata automatically"
