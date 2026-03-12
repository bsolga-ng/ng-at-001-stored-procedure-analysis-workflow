---
command: sp-change-prep
description: Pre-change impact analysis + validation scripts for a stored procedure modification
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-11 20:00 UTC+0200
---

# SP Change Preparation

Prepare for a stored procedure modification: assess impact, generate validation scripts, and create a change checklist.

## Arguments
- `$ARGUMENTS` - SP name + optional description of the planned change

## Instructions

### Step 1: Load Existing Analysis

Check for existing documentation:
- `docs/sp-analysis/{schema}/{sp-name}.md` — load if exists
- If not found, run `/sp-analyze $SP_NAME --quick` first

### Step 2: Understand the Change

Ask the developer:
1. "What change are you making to this SP?" (brief description)
2. "Which parameters or tables are affected?"
3. "Is this a bug fix, performance optimization, or feature change?"

### Step 3: Impact Analysis

Based on the planned change and blast radius data:

```markdown
# Change Impact: {SP Name}

**Planned change**: {description}
**Type**: {Bug fix / Performance / Feature}
**Blast radius**: {Low/Medium/High}

## Affected Consumers

| Consumer | Risk | Reason |
|----------|------|--------|
| {Endpoint/Service} | {Low/Med/High} | {Parameter change / Result set change / Logic change} |

## Parameter Impact

| Parameter | Current | After Change | Consumers Affected |
|-----------|---------|-------------|-------------------|
| {param} | {type/default} | {new type/default} | {N} callers |

## Result Set Impact

| Column | Current | After Change | Consumers Affected |
|--------|---------|-------------|-------------------|
| {col} | {type} | {changed how} | {N} consumers |
```

### Step 4: Generate Validation Scripts

Generate PowerShell scripts the developer can run before AND after making the change:

#### Pre-Change Snapshot Script
```powershell
# Save current SP behavior as baseline
# Developer fills in realistic parameter values
$params = @{
    Param1 = 'value1'
    Param2 = 'value2'
}
.\scripts\powershell\Test-SpChange.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "{sp_name}" `
    -Parameters $params `
    -Phase "before" `
    -OutputDir "docs/sp-analysis/{schema}/validation/"
```

#### Post-Change Comparison Script
```powershell
# Compare SP output after the change
.\scripts\powershell\Test-SpChange.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "{sp_name}" `
    -Parameters $params `
    -Phase "after" `
    -OutputDir "docs/sp-analysis/{schema}/validation/"
```

### Step 5: Change Checklist

```markdown
## Change Checklist

### Before Making the Change
- [ ] Existing SP analysis reviewed (`docs/sp-analysis/{schema}/{sp-name}.md`)
- [ ] Blast radius understood — {N} consumers identified
- [ ] Pre-change snapshot captured (run validation script with `--Phase before`)
- [ ] Affected .NET consumers identified for testing

### During the Change
- [ ] SP modification implemented
- [ ] Dynamic SQL reviewed for injection risk (if applicable)
- [ ] Temp table lifecycle unchanged (if applicable)

### After the Change
- [ ] Post-change snapshot captured (run validation script with `--Phase after`)
- [ ] Result set diff reviewed — expected changes only
- [ ] Affected .NET endpoints manually tested
- [ ] xUnit tests pass for affected repositories
- [ ] Performance validated (if performance-related change):
  - [ ] Execution plan reviewed in SSMS
  - [ ] Run `Export-ExecutionPlan.ps1` and compare
- [ ] PR created with change description referencing blast radius
```

### Output

Save to: `docs/sp-analysis/{schema}/{sp-name}-change-{date}.md`

### Quality Gate

| Criterion | Pass |
|-----------|------|
| Existing analysis loaded or generated | [ ] |
| Impact on consumers documented | [ ] |
| Validation scripts generated | [ ] |
| Change checklist complete | [ ] |
