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

## Level 2: SQL Server MCP Integration

> **If the `microsoft-sql` MCP server is enabled**, Claude Code can query the database directly — replacing most PowerShell bridge scripts with live queries. This is the recommended setup when MCP is available.

### What MCP Replaces

| PowerShell Script | MCP Equivalent | Still Needed? |
|-------------------|----------------|---------------|
| `Export-SpDefinitions.ps1` | Claude Code queries `OBJECT_DEFINITION()` directly | **No** — MCP replaces entirely |
| `Export-SpMetadata.ps1` | Claude Code queries `sys.parameters`, `sys.sql_expression_dependencies`, `sys.indexes` | **No** — MCP replaces entirely |
| `Get-SpStats.ps1` | Claude Code queries `sys.dm_exec_procedure_stats` | **No** — MCP replaces entirely |
| `Export-ExecutionPlan.ps1` | Claude Code runs `SET SHOWPLAN_XML ON` via MCP | **No** — MCP replaces entirely |
| `Test-SpChange.ps1` | **Keep** — executes SPs with real params; regression diff needs before/after snapshots | **Yes** — still needed for validation |

### Enabling MCP

The NeoGov cc-templates include a pre-configured `microsoft-sql` MCP server (disabled by default).

```bash
# Check if MCP is configured
claude mcp list

# If microsoft-sql is listed but disabled, enable it:
# Edit ~/.claude.json and set "disabled": false for microsoft-sql
```

Alternatively, add the SQL Server MCP server directly:

```bash
claude mcp add --transport stdio microsoft-sql -- \
  npx -y @anthropic/mcp-server-sql-server \
  --connection-string "Server=localhost;Database=AttractDB;Trusted_Connection=True"
```

### MCP Workflow (replaces Stages 1.1–1.3)

With MCP enabled, skip the PowerShell export steps entirely:

```bash
# 1. Install commands (still needed)
./scripts/install.sh /path/to/your-dotnet-project

# 2. Navigate and start Claude Code
cd /path/to/your-dotnet-project
claude

# 3. Build registry — /sp-discover now queries DB directly via MCP
/sp-discover src

# 4. Analyze — /sp-analyze uses MCP for live metadata, params, dependencies
/sp-analyze DataSync.GetJobsForSync
```

Claude Code will automatically detect the MCP server and use it for:
- Fetching SP definitions (`OBJECT_DEFINITION()`)
- Querying parameters and dependencies (`sys.parameters`, `sys.sql_expression_dependencies`)
- Retrieving runtime stats (`sys.dm_exec_procedure_stats`)
- Generating execution plans (`SET SHOWPLAN_XML ON`)

### When to Keep PowerShell Scripts

| Scenario | Use |
|----------|-----|
| MCP not available (policy restriction, no DB access from dev machine) | PowerShell scripts |
| Before/after regression testing | `Test-SpChange.ps1` (always) |
| CI/CD integration (export on merge) | PowerShell scripts |
| Offline analysis (disconnected from DB) | PowerShell exports |

### MCP + PowerShell Together

The two approaches are complementary:
1. **MCP for live exploration**: Real-time queries during analysis sessions
2. **PowerShell for snapshots**: Deterministic exports committed to Git for version tracking and offline use
3. **Test-SpChange.ps1 always**: Before/after regression validation regardless of MCP status

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| SP definition not found | Run `Export-SpDefinitions.ps1` or check repo path. With MCP, Claude Code fetches directly. |
| No .NET references found | Check search patterns — may use constants or enums for SP names |
| PowerShell scripts fail to connect | Verify connection string, check firewall, try with `-Credential` |
| Azure SQL connection refused | Add `-UseAzureAD` flag. Requires `SqlServer` module: `Install-Module SqlServer -Scope CurrentUser` |
| `System.Data.SqlClient` not found | Install SqlServer module for `Microsoft.Data.SqlClient`: `Install-Module SqlServer -Scope CurrentUser` |
| MCP server not connecting | Check `claude mcp list`. Verify connection string in `~/.claude.json`. Restart Claude Code after config change. |
| Metadata export slow | Filter by SP name or schema to reduce scope |
| Execution plan empty | SP may use dynamic SQL — try with actual parameters. Requires `SHOWPLAN` permission. |
| Diff shows unexpected changes | Check if other SP changes were deployed between before/after |
