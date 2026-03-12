<#
.SYNOPSIS
    Capture SP execution results before and after a change for regression comparison.

.DESCRIPTION
    Runs a stored procedure with given parameters and captures:
    - Result sets (as CSV)
    - Row counts
    - Execution time
    - Output parameter values

    Run with -Phase "before" to capture baseline, then -Phase "after" to capture
    post-change results. Automatically generates a diff report when "after" is run.

.PARAMETER ServerInstance
    SQL Server instance name

.PARAMETER Database
    Database name

.PARAMETER SpName
    Stored procedure name (schema-qualified)

.PARAMETER Parameters
    Hashtable of parameter names and values

.PARAMETER Phase
    "before" or "after" — determines file naming and diff generation

.PARAMETER OutputDir
    Output directory (default: docs/sp-analysis/validation)

.PARAMETER Credential
    Optional: SQL auth credential

.EXAMPLE
    $params = @{ JobId = 123 }

    # Before the change
    .\Test-SpChange.ps1 -ServerInstance "localhost" -Database "AttractDB" `
        -SpName "DataSync.GetJobsForSync" -Parameters $params -Phase "before"

    # (make your SP change)

    # After the change
    .\Test-SpChange.ps1 -ServerInstance "localhost" -Database "AttractDB" `
        -SpName "DataSync.GetJobsForSync" -Parameters $params -Phase "after"
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

    [Parameter(Mandatory)]
    [ValidateSet("before", "after")]
    [string]$Phase,

    [string]$OutputDir = "docs/sp-analysis/validation",

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
$safeName = $SpName -replace '\.', '_'
$spOutputDir = Join-Path $OutputDir $safeName
New-Item -ItemType Directory -Path $spOutputDir -Force | Out-Null

$connection = New-Object System.Data.SqlClient.SqlConnection($connString)
$connection.Open()

try {
    # Build command
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = $SpName
    $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $cmd.CommandTimeout = 300

    foreach ($p in $Parameters.GetEnumerator()) {
        $cmd.Parameters.AddWithValue("@$($p.Key)", $p.Value) | Out-Null
    }

    # Execute and capture
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dataSet = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $stopwatch.Stop()

    # Save results
    $summary = @{
        SpName       = $SpName
        Phase        = $Phase
        Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Parameters   = $Parameters
        ElapsedMs    = $stopwatch.ElapsedMilliseconds
        ResultSets   = $dataSet.Tables.Count
        TotalRows    = ($dataSet.Tables | ForEach-Object { $_.Rows.Count } | Measure-Object -Sum).Sum
    }

    # Save each result set as CSV
    $resultSetDetails = @()
    for ($i = 0; $i -lt $dataSet.Tables.Count; $i++) {
        $table = $dataSet.Tables[$i]
        $csvPath = Join-Path $spOutputDir "${Phase}_resultset_${i}.csv"
        $table | Export-Csv -Path $csvPath -NoTypeInformation -Encoding utf8

        $resultSetDetails += [PSCustomObject]@{
            Index   = $i
            Rows    = $table.Rows.Count
            Columns = $table.Columns.Count
            File    = $csvPath
        }

        Write-Host "  ResultSet[$i]: $($table.Rows.Count) rows, $($table.Columns.Count) columns" -ForegroundColor Green
    }

    $summary["ResultSetDetails"] = $resultSetDetails

    # Save summary
    $summaryPath = Join-Path $spOutputDir "${Phase}_summary.json"
    $summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding utf8

    Write-Host "`n--- $Phase Snapshot Complete ---" -ForegroundColor Cyan
    Write-Host "SP: $SpName"
    Write-Host "Execution time: $($stopwatch.ElapsedMilliseconds)ms"
    Write-Host "Result sets: $($dataSet.Tables.Count)"
    Write-Host "Total rows: $(($dataSet.Tables | ForEach-Object { $_.Rows.Count } | Measure-Object -Sum).Sum)"
    Write-Host "Output: $spOutputDir"

    # Generate diff if "after" phase
    if ($Phase -eq "after") {
        $beforeSummaryPath = Join-Path $spOutputDir "before_summary.json"
        if (Test-Path $beforeSummaryPath) {
            $beforeSummary = Get-Content $beforeSummaryPath | ConvertFrom-Json

            $diffLines = @()
            $diffLines += "# SP Change Validation: $SpName"
            $diffLines += ""
            $diffLines += "## Execution Time"
            $diffLines += "| Phase | Time (ms) |"
            $diffLines += "|-------|-----------|"
            $diffLines += "| Before | $($beforeSummary.ElapsedMs) |"
            $diffLines += "| After | $($summary.ElapsedMs) |"
            $diffLines += "| Delta | $(($summary.ElapsedMs) - ($beforeSummary.ElapsedMs)) |"
            $diffLines += ""

            $diffLines += "## Row Counts"
            $diffLines += "| Phase | Total Rows |"
            $diffLines += "|-------|------------|"
            $diffLines += "| Before | $($beforeSummary.TotalRows) |"
            $diffLines += "| After | $($summary.TotalRows) |"
            $diffLines += ""

            # Compare result sets
            $maxSets = [Math]::Max($beforeSummary.ResultSets, $summary.ResultSets)
            for ($i = 0; $i -lt $maxSets; $i++) {
                $beforeCsv = Join-Path $spOutputDir "before_resultset_${i}.csv"
                $afterCsv = Join-Path $spOutputDir "after_resultset_${i}.csv"

                if ((Test-Path $beforeCsv) -and (Test-Path $afterCsv)) {
                    $beforeContent = Get-Content $beforeCsv
                    $afterContent = Get-Content $afterCsv

                    if ($beforeContent.Count -eq $afterContent.Count) {
                        $identical = ($beforeContent -join "`n") -eq ($afterContent -join "`n")
                        if ($identical) {
                            $diffLines += "### ResultSet[$i]: IDENTICAL"
                        } else {
                            $diffLines += "### ResultSet[$i]: CHANGED (same row count, different data)"
                            $diffLines += "Review CSV files manually for detailed differences."
                        }
                    } else {
                        $diffLines += "### ResultSet[$i]: ROW COUNT CHANGED ($($beforeContent.Count - 1) -> $($afterContent.Count - 1))"
                    }
                } elseif (Test-Path $beforeCsv) {
                    $diffLines += "### ResultSet[$i]: REMOVED in after phase"
                } elseif (Test-Path $afterCsv) {
                    $diffLines += "### ResultSet[$i]: NEW in after phase"
                }
                $diffLines += ""
            }

            $diffPath = Join-Path $spOutputDir "diff_report.md"
            $diffLines -join "`n" | Out-File -FilePath $diffPath -Encoding utf8

            Write-Host "`n--- Diff Report Generated ---" -ForegroundColor Yellow
            Write-Host "Report: $diffPath"
            Write-Host "Feed this to Claude Code for analysis: /sp-analyze review the diff at $diffPath"
        } else {
            Write-Warning "'before' snapshot not found. Run with -Phase 'before' first to enable comparison."
        }
    }

} finally {
    $connection.Close()
}
