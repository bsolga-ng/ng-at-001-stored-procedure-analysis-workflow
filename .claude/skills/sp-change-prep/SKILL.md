---
name: neogov:workflow:sp-change-prep
description: Prepare for stored procedure modification — impact analysis, regression risk assessment, and validation script generation. Use when a developer says they need to change, fix, modify, or optimize a SQL Server stored procedure, mentions a Jira ticket involving SP changes, or when sp-analysis identifies a modification intent. Generates pre/post-change validation scripts using Test-SpChange.ps1, impact tables for affected consumers, and a change checklist.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *), Bash(pwsh *)
---

# SP Change Preparation

Prepare for a stored procedure modification: assess impact on .NET consumers, generate validation scripts for regression testing, and create a structured change checklist.

## When This Skill Triggers

- Developer says "I need to change/fix/modify/optimize this SP"
- Developer mentions a Jira ticket that involves SP modification
- `neogov:workflow:sp-analysis` detected the developer intends to modify an SP
- Developer asks about the impact of changing an SP's parameters, result set, or logic
- Developer mentions regression risk for a stored procedure change

## Step 1: Load Existing Analysis

Check for prior analysis output:
- `docs/sp-analysis/{schema}/{sp-name}.md` — load if exists
- If not found, trigger `neogov:workflow:sp-analysis` first (the analysis skill)

## Step 2: Understand the Change

Ask the developer:
1. "What change are you making to this SP?" (brief description)
2. "Which parameters or tables are affected?"
3. "Is this a bug fix, performance optimization, or feature change?"

## Step 3: Impact Analysis

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

## Step 4: Generate Validation Scripts

Generate PowerShell commands the developer can run before AND after the change:

### Pre-Change Snapshot
```powershell
$params = @{
    Param1 = 'value1'  # Developer fills in realistic values
    Param2 = 'value2'
}
pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "{sp_name}" `
    -Parameters $params `
    -Phase "before"
```

### Post-Change Comparison
```powershell
pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "{sp_name}" `
    -Parameters $params `
    -Phase "after"
```

Note: `Test-SpChange.ps1` automatically generates a diff report when the "after" phase runs.

## Step 5: Change Checklist

```markdown
## Change Checklist

### Before Making the Change
- [ ] Existing SP analysis reviewed
- [ ] Blast radius understood — {N} consumers identified
- [ ] Pre-change snapshot captured (`Test-SpChange.ps1 -Phase before`)
- [ ] Affected .NET consumers identified for testing

### During the Change
- [ ] SP modification implemented
- [ ] Dynamic SQL reviewed for injection risk (if applicable)
- [ ] Temp table lifecycle unchanged (if applicable)

### After the Change
- [ ] Post-change snapshot captured (`Test-SpChange.ps1 -Phase after`)
- [ ] Diff report reviewed — expected changes only
- [ ] Affected .NET endpoints manually tested
- [ ] xUnit tests pass for affected repositories
- [ ] Performance validated (if performance-related):
  - [ ] Execution plan compared (`Export-ExecutionPlan.ps1`)
- [ ] Documentation updated (triggers neogov:workflow:sp-document)
- [ ] Changes committed (`/git:commit`) and PR created (`/pr:create`)
```

## Output

Save to: `docs/sp-analysis/{schema}/{sp-name}-change-{date}.md`

## Quality Gate

- [ ] Existing analysis loaded or generated
- [ ] Impact on consumers documented
- [ ] Validation scripts generated with realistic parameter templates
- [ ] Change checklist complete

## Composition

- Requires `neogov:workflow:sp-analysis` output (auto-triggers if missing)
- References `Test-SpChange.ps1` for regression validation (PowerShell, always needed regardless of MCP)
- Checklist references `/git:commit` and `/pr:create` for commit/PR steps — does NOT embed git logic
- Checklist references `neogov:workflow:sp-document` for post-change documentation update
- Works alongside superpowers `test-driven-development` — change prep produces test suggestions compatible with TDD cycle
- Works alongside superpowers `verification-before-completion` — diff report is verifiable evidence
