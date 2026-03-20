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

.PARAMETER UseAzureAD
    Switch: Use Azure AD Interactive authentication (for Azure SQL)

.EXAMPLE
    .\Export-SpMetadata.ps1 -ServerInstance "localhost" -Database "AttractDB"
    .\Export-SpMetadata.ps1 -ServerInstance "localhost" -Database "AttractDB" -SpName "DataSync.GetJobsForSync"
    .\Export-SpMetadata.ps1 -ServerInstance "server.database.windows.net" -Database "AttractDB" -UseAzureAD
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [Parameter(Mandatory)]
    [string]$Database,

    [string]$SpName = "",

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

function Invoke-ParameterizedQuery {
    param(
        [string]$ConnString,
        [string]$Query,
        [hashtable]$Parameters = @{}
    )
    $conn = New-SqlConnection -ConnString $ConnString
    $conn.Open()
    try {
        if ($useMds) {
            $cmd = [Microsoft.Data.SqlClient.SqlCommand]::new($Query, $conn)
            $adapter = [Microsoft.Data.SqlClient.SqlDataAdapter]::new($cmd)
        } else {
            $cmd = [System.Data.SqlClient.SqlCommand]::new($Query, $conn)
            $adapter = [System.Data.SqlClient.SqlDataAdapter]::new($cmd)
        }
        $cmd.CommandTimeout = 120
        foreach ($p in $Parameters.GetEnumerator()) {
            $cmd.Parameters.AddWithValue($p.Key, $p.Value) | Out-Null
        }
        $table = New-Object System.Data.DataTable
        $adapter.Fill($table) | Out-Null
        return $table
    } finally {
        $conn.Close()
    }
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

# Get SP list with parameterized filter
$spQuery = @"
SELECT s.name AS [Schema], p.name AS [Name], p.object_id
FROM sys.procedures p
JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE 1=1
"@

$spParams = @{}
if ($SpName) {
    if ($SpName -match '\.') {
        $parts = $SpName -split '\.'
        $spQuery += " AND s.name = @SchemaFilter AND p.name LIKE @NameFilter"
        $spParams["@SchemaFilter"] = $parts[0]
        $spParams["@NameFilter"] = $parts[1].Replace('*', '%')
    } else {
        $spQuery += " AND p.name LIKE @NameFilter"
        $spParams["@NameFilter"] = $SpName.Replace('*', '%')
    }
}
$spQuery += " ORDER BY s.name, p.name"

$spList = Invoke-ParameterizedQuery -ConnString $connString -Query $spQuery -Parameters $spParams

$allMetadata = @()

foreach ($sp in $spList.Rows) {
    $schemaVal = $sp.Schema
    $name = $sp.Name
    $objectId = [int]$sp.object_id
    Write-Host "Processing: $schemaVal.$name" -ForegroundColor Yellow

    # Parameters
    $params = Invoke-ParameterizedQuery -ConnString $connString -Query @"
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
WHERE par.object_id = @ObjectId
ORDER BY par.parameter_id
"@ -Parameters @{ "@ObjectId" = $objectId }

    # Table/View dependencies
    $dependencies = Invoke-ParameterizedQuery -ConnString $connString -Query @"
SELECT DISTINCT
    COALESCE(d.referenced_schema_name, 'dbo') AS [Schema],
    d.referenced_entity_name AS [Name],
    o.type_desc AS [Type]
FROM sys.sql_expression_dependencies d
LEFT JOIN sys.objects o ON o.name = d.referenced_entity_name
    AND o.schema_id = SCHEMA_ID(COALESCE(d.referenced_schema_name, 'dbo'))
WHERE d.referencing_id = @ObjectId
    AND d.referenced_entity_name IS NOT NULL
ORDER BY d.referenced_entity_name
"@ -Parameters @{ "@ObjectId" = $objectId }

    # Cross-SP dependencies (SPs that call this SP)
    $callers = Invoke-ParameterizedQuery -ConnString $connString -Query @"
SELECT DISTINCT
    SCHEMA_NAME(o.schema_id) AS [CallerSchema],
    o.name AS [CallerName],
    o.type_desc AS [CallerType]
FROM sys.sql_expression_dependencies d
JOIN sys.objects o ON o.object_id = d.referencing_id
WHERE d.referenced_entity_name = @SpName
    AND COALESCE(d.referenced_schema_name, 'dbo') = @SchemaName
    AND o.object_id != @ObjectId
ORDER BY o.name
"@ -Parameters @{
        "@SpName" = $name
        "@SchemaName" = $schemaVal
        "@ObjectId" = $objectId
    }

    # Index info for referenced tables
    $tableNames = @($dependencies.Rows | Where-Object { $_.Type -match 'TABLE' } | ForEach-Object { $_.Name })
    $indexes = @()
    if ($tableNames.Count -gt 0) {
        # Build parameterized IN clause
        $inParams = @{}
        $inPlaceholders = @()
        for ($i = 0; $i -lt $tableNames.Count; $i++) {
            $paramName = "@Table$i"
            $inParams[$paramName] = $tableNames[$i]
            $inPlaceholders += $paramName
        }
        $inClause = $inPlaceholders -join ','

        $indexes = Invoke-ParameterizedQuery -ConnString $connString -Query @"
SELECT
    OBJECT_NAME(i.object_id) AS [Table],
    i.name AS [IndexName],
    i.type_desc AS [IndexType],
    STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS [Columns]
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) IN ($inClause)
    AND i.name IS NOT NULL
GROUP BY i.object_id, i.name, i.type_desc
ORDER BY OBJECT_NAME(i.object_id), i.name
"@ -Parameters $inParams
    }

    $spMetadata = [PSCustomObject]@{
        Schema       = $schemaVal
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
