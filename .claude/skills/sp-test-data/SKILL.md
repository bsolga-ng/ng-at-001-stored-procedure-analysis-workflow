---
name: neogov:workflow:sp-test-data
description: Generate sample test data and parameter values for testing stored procedure changes locally. Use when a developer wants to test an SP change, needs sample parameter values, is onboarding a new colleague to the SP workflow, or says "I want to test this SP locally". Generates realistic parameter sets, lookup queries for FK values, and before/after validation scripts.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *), Bash(pwsh *), Bash(sqlcmd *)
---

# SP Test Data Generator

Generate realistic sample data for testing stored procedure changes locally. Designed for two use cases:
1. **Testing a change** — developer modified an SP and needs to validate it
2. **New colleague onboarding** — new team member needs to understand and safely experiment with SPs

## When This Skill Triggers

- Developer says "I want to test this SP locally"
- Developer says "give me sample data for this SP"
- Developer says "how do I test this change?"
- Developer is new and asks "how do I try this out safely?"
- Developer modified an SP and asks "how do I validate this?"
- `neogov:workflow:sp-quick-fix` needs test data during validation
- `neogov:workflow:sp-change-prep` needs parameter templates for validation scripts

## Step 1: Read SP Parameters

Load the SP definition and extract all parameters:

```
Parameters for {Schema}.{SpName}:

  @CandidateId    INT              — required, no default
  @DepartmentId   INT              — optional, default NULL
  @Status         VARCHAR(50)      — optional, default 'Active'
  @StartDate      DATETIME         — optional, default GETDATE()
  @PageSize       INT              — optional, default 25
  @PageNumber     INT              — optional, default 1
```

## Step 2: Generate Realistic Sample Values

For each parameter, generate a value based on type + name semantics:

### Value Generation Rules

| Parameter Pattern | Sample Value | Logic |
|------------------|-------------|-------|
| `*Id` (INT) | `12345` | Generic ID + lookup query to find real ones |
| `*Date`, `*Time` (DATETIME) | `'2026-03-01'` | Recent date within likely data range |
| `*Name`, `*Text` (VARCHAR) | `'Test Value'` | Short descriptive string |
| `*Status` (VARCHAR) | `'Active'` | Most common enum value (infer from SP logic) |
| `*Flag`, `Is*` (BIT) | `1` | Default to true |
| `*Count`, `*Size` (INT) | `25` | Sensible default |
| `*Page*` (INT) | `1` | First page |
| `*Email` (VARCHAR) | `'test@example.com'` | Valid format |
| `*Amount`, `*Price` (DECIMAL) | `100.00` | Round number |
| OUTPUT params | N/A | Marked as output — captured in results |

### Lookup Queries for FK References

For any `*Id` parameter that references another table (detected from SP JOINs or FK constraints):

```sql
-- Find valid CandidateId values to test with:
SELECT TOP 10 CandidateId, FirstName, LastName, Status
FROM dbo.Candidates
WHERE Status = 'Active'
ORDER BY CandidateId DESC

-- Find valid DepartmentId values:
SELECT TOP 10 DepartmentId, Name
FROM dbo.Departments
ORDER BY Name
```

## Step 3: Generate Test Script

Produce a ready-to-run PowerShell script:

```powershell
# ============================================
# Test Script for {Schema}.{SpName}
# Generated: {date}
# ============================================

# --- Sample parameters (edit values as needed) ---
$params = @{
    CandidateId  = 12345           # INT — find real IDs: SELECT TOP 5 CandidateId FROM dbo.Candidates
    DepartmentId = 1               # INT (optional) — NULL for all departments
    Status       = 'Active'        # VARCHAR(50) — common values: Active, Inactive, Pending
    StartDate    = '2026-01-01'    # DATETIME — adjust to your data range
    PageSize     = 50              # INT — default 25, set higher for testing
}

# --- Connection (adjust to your local setup) ---
$server = "localhost"              # Or "localhost\SQLEXPRESS" or Docker container
$database = "AttractDB"            # Your local DB name

# --- Capture BEFORE snapshot ---
Write-Host "Capturing BEFORE snapshot..." -ForegroundColor Yellow
pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance $server -Database $database `
    -SpName "{Schema}.{SpName}" -Parameters $params -Phase "before"

# --- Make your SP change here ---
Write-Host ""
Write-Host ">>> Now make your SP change, then press Enter to capture AFTER <<<" -ForegroundColor Cyan
Read-Host

# --- Capture AFTER snapshot ---
Write-Host "Capturing AFTER snapshot..." -ForegroundColor Yellow
pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance $server -Database $database `
    -SpName "{Schema}.{SpName}" -Parameters $params -Phase "after"

Write-Host ""
Write-Host "Diff report generated at: docs/sp-analysis/validation/{sp_name}/diff_report.md" -ForegroundColor Green
Write-Host "Review it to confirm your change produces the expected result." -ForegroundColor Green
```

## Step 4: Edge Case Test Sets (for thorough testing)

Generate multiple parameter combinations to cover edge cases:

```powershell
# --- Test Set 1: Happy path (typical usage) ---
$happyPath = @{
    CandidateId = 12345
    Status = 'Active'
    PageSize = 25
}

# --- Test Set 2: NULL optional parameters ---
$nullOptionals = @{
    CandidateId = 12345
    # DepartmentId omitted — tests NULL handling
    # Status omitted — tests default value
}

# --- Test Set 3: Boundary values ---
$boundaries = @{
    CandidateId = 1               # Minimum valid ID
    PageSize = 1                  # Minimum page size
    StartDate = '2020-01-01'      # Old date — tests range
}

# --- Test Set 4: Large result set ---
$largeResult = @{
    PageSize = 1000               # Large page — tests performance
}

# Run each test set:
foreach ($testName in @('happyPath', 'nullOptionals', 'boundaries', 'largeResult')) {
    $testParams = Get-Variable -Name $testName -ValueOnly
    Write-Host "Running test: $testName" -ForegroundColor Yellow
    pwsh scripts/powershell/Test-SpChange.ps1 `
        -ServerInstance $server -Database $database `
        -SpName "{Schema}.{SpName}" -Parameters $testParams -Phase "before"
}
```

## Step 5: New Colleague Onboarding Mode

When the developer is new to the team or this SP, provide additional context:

### Safe Experimentation Guide

```markdown
## Safe SP Testing Guide for {SpName}

### Before you start
1. You're working on a LOCAL database copy — changes here don't affect QA or prod
2. The Test-SpChange.ps1 script captures snapshots — you can always compare before/after
3. Start with the happy path test set, then try edge cases

### Try these exercises:
1. **Read the analysis first**: `docs/sp-analysis/{schema}/{sp-name}.md`
2. **Run the SP with sample data**: Use the test script above
3. **Make a simple change**: Try one of these safe modifications:
   - Add a new optional parameter with a default value
   - Change a column alias in a SELECT
   - Add a WHERE condition that filters by an existing column
4. **Run the AFTER snapshot**: Compare with the BEFORE to see what changed
5. **Revert your change**: `git checkout -- {sp-file-path}`

### What to observe:
- How many result sets does the SP return?
- What columns are in each result set?
- How many rows come back with the sample parameters?
- What happens when you pass NULL for optional parameters?
```

### Suggested First Changes (for learning)

Based on the SP's parameters, suggest safe modifications the new developer can try:

| Change | What to Do | Expected Impact | How to Verify |
|--------|-----------|----------------|---------------|
| Add optional parameter | Add `@NewParam INT = NULL` to parameter list | No impact — default is NULL | Result sets unchanged |
| Rename output column | Change `SELECT col AS OldName` to `SELECT col AS NewName` | Column name changes | Check diff report |
| Add filter | Add `AND Status = @Status` to WHERE clause | Fewer rows if Status is passed | Compare row counts |
| Change data type | Widen `VARCHAR(50)` to `VARCHAR(100)` | No impact on existing data | Result sets unchanged |

After each change, run the test script and review the diff report. This builds confidence with the workflow before tackling real tasks.

## Output

- Test script saved to: `docs/sp-analysis/validation/{sp-name}/test-script.ps1`
- Lookup queries saved to: `docs/sp-analysis/validation/{sp-name}/lookup-queries.sql`

## Quality Gate

- [ ] All parameters identified with types and defaults
- [ ] Sample values are realistic (not just placeholder zeros)
- [ ] Lookup queries provided for FK references
- [ ] Test script is copy-paste ready (correct server, database, SP name)
- [ ] Edge case test sets cover NULL handling and boundaries
- [ ] If onboarding mode: safe experimentation guide included

## Composition

- Reads SP definition from repo or `neogov:workflow:sp-analysis` output
- Used by `neogov:workflow:sp-quick-fix` (Step 5: Generate Test Data)
- Used by `neogov:workflow:sp-change-prep` (Step 4: Validation Scripts parameter templates)
- Lookup queries use MCP or `sqlcmd` if available; otherwise document as manual queries
