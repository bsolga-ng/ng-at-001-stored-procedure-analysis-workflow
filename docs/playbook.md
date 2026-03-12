# SP Analysis Workflow — Playbook

> Step-by-step guide for applying the SP analysis methodology.
> For the full README, see: [../README.md](../README.md)

---

## Getting Started

### What You Need

1. **A .NET codebase** that calls stored procedures
2. **Claude Code** installed and configured
3. **SP definitions** either:
   - Already in the Git repo as `.sql` files, OR
   - Exported using `Export-SpDefinitions.ps1`
4. **PowerShell Core** (optional but recommended for database bridge scripts)

### Quick Start

```bash
# 1. Install commands in your target repo
./scripts/install.sh /path/to/your-dotnet-project

# 2. Navigate to your codebase
cd /path/to/your-dotnet-project
claude

# 3. Build the SP registry (run once)
/sp-discover src

# 4. Analyze the SP you need to work on
/sp-analyze DataSync.GetJobsForSync
```

---

## Stage Overview

| Stage | Command | Cardinality | Input → Output |
|-------|---------|-------------|----------------|
| **1. Setup** | PowerShell scripts | 1x initial | DB → .sql files + metadata |
| **2. Discovery** | `/sp-discover` | 1x per repo | .NET code → SP registry |
| **3. Analysis** | `/sp-analyze` | Per SP task | SP + .NET code → analysis doc |
| **4. Change Prep** | `/sp-change-prep` | Per SP modification | Analysis → impact + validation |
| **5. Validation** | `Test-SpChange.ps1` | Per SP modification | Before/after → diff report |

---

## Stage 1: Setup (One-Time)

### 1.1 Export SP Definitions

If SP definitions are NOT in your Git repository:

```powershell
# Export all SPs to docs/sp-definitions/
pwsh scripts/powershell/Export-SpDefinitions.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB"

# Or export specific SPs
pwsh scripts/powershell/Export-SpDefinitions.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "DataSync.*"
```

### 1.2 Export Metadata (Recommended)

```powershell
# Export parameter info, dependencies, and indexes
pwsh scripts/powershell/Export-SpMetadata.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB"
```

### 1.3 Export Runtime Stats (Optional)

```powershell
# Get top 50 SPs by execution time — helps prioritize
pwsh scripts/powershell/Get-SpStats.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB"
```

### Quality Gate

| Check | Status |
|-------|--------|
| SP definitions exported or in repo | [ ] |
| Metadata exported (recommended) | [ ] |
| Runtime stats exported (optional) | [ ] |
| Files committed to repo | [ ] |

---

## Stage 2: Discovery

```bash
/sp-discover src
```

**Output**: `docs/sp-analysis/_index.md` — registry of all SP references in .NET code

### Quality Gate

| Check | Status |
|-------|--------|
| All .NET data access patterns scanned | [ ] |
| SP names matched to definition files | [ ] |
| Missing definitions flagged | [ ] |
| Registry saved | [ ] |

---

## Stage 3: Analysis (Per SP)

```bash
/sp-analyze DataSync.GetJobsForSync
```

**Interactive mode** asks about your task type and focus. Use `--quick` to skip.

**Output**: `docs/sp-analysis/{schema}/{sp-name}.md` — full analysis document

### What Gets Generated

- Parameter documentation
- Table/view dependency map
- Logic flow with conditional branches
- Dynamic SQL detection and analysis
- .NET invocation points (blast radius)
- Mermaid diagrams (execution flow, invocation map, ER)
- Optimization suggestions
- Risk assessment

### Quality Gate

| Check | Status |
|-------|--------|
| SP definition parsed | [ ] |
| Parameters documented | [ ] |
| Tables and operations listed | [ ] |
| .NET invocation points found | [ ] |
| Blast radius rated | [ ] |
| Diagrams render | [ ] |
| `[inferred]` items flagged | [ ] |

---

## Stage 4: Change Preparation

```bash
/sp-change-prep DataSync.GetJobsForSync
```

**Output**: Impact analysis + validation scripts + change checklist

### Pre-Change Snapshot

```powershell
$params = @{ JobId = 123; SyncType = 'Full' }
pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "DataSync.GetJobsForSync" `
    -Parameters $params `
    -Phase "before"
```

---

## Stage 5: Post-Change Validation

After making your SP change:

```powershell
# Capture post-change results (same params)
pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance "localhost" `
    -Database "AttractDB" `
    -SpName "DataSync.GetJobsForSync" `
    -Parameters $params `
    -Phase "after"
```

This automatically generates a diff report comparing before/after:
- Execution time delta
- Row count changes
- Result set differences

Feed the diff to Claude Code for analysis:
```bash
# In Claude Code
"Review the SP change validation at docs/sp-analysis/validation/DataSync_GetJobsForSync/diff_report.md"
```

---

## Workflow Summary

```
Developer assigned SP task
        │
        ▼
/sp-analyze {sp-name}                     ← Claude Code: understand the SP
        │
        ▼
/sp-change-prep {sp-name}                 ← Claude Code: impact analysis
        │
        ▼
Test-SpChange.ps1 -Phase "before"         ← PowerShell: capture baseline
        │
        ▼
(Developer makes the SP change)
        │
        ▼
Test-SpChange.ps1 -Phase "after"          ← PowerShell: capture post-change
        │
        ▼
Review diff_report.md                     ← Claude Code or manual review
        │
        ▼
/sp-document {sp-name} --refresh          ← Claude Code: update docs
        │
        ▼
Commit + PR
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SP definition not found | Run `Export-SpDefinitions.ps1` or check repo path |
| No .NET references found | Check search patterns — may use constants or enums for SP names |
| PowerShell scripts fail to connect | Verify connection string, check firewall, try with `-Credential` |
| Metadata export slow | Filter by SP name or schema to reduce scope |
| Execution plan empty | SP may use dynamic SQL — try with actual parameters |
| Diff shows unexpected changes | Check if other SP changes were deployed between before/after |
