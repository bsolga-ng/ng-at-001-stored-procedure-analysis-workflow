# Limitations & Mitigations

Claude Code operates on files in a filesystem. It cannot connect to databases, execute queries, or observe runtime behavior. This document maps each limitation to concrete mitigations using PowerShell scripts that produce deterministic outputs for Claude Code to analyze.

**Design principle**: Minimize HITL (human-in-the-loop) work by converting each limitation into a scripted bridge — the developer runs a script once, Claude Code consumes the output automatically.

---

## Limitation Matrix

| # | Limitation | Impact | PowerShell Mitigation | Claude Code Integration | HITL Remaining |
|---|-----------|--------|----------------------|------------------------|---------------|
| 1 | Cannot connect to databases | Cannot read SP definitions directly | `Export-SpDefinitions.ps1` | Reads exported `.sql` files automatically | One-time setup; re-run when SPs change |
| 2 | Cannot execute SPs | Cannot observe runtime behavior | `Test-SpChange.ps1` | Reads before/after CSVs + diff report | Developer fills parameter values, runs script |
| 3 | Cannot read live execution plans | Cannot analyze query performance dynamically | `Export-ExecutionPlan.ps1` | Reads plan summary `.md` file | Developer runs script with realistic params |
| 4 | Static analysis only | May miss runtime-only behaviors (dynamic SQL, conditional paths) | `Export-SpMetadata.ps1` | Reads metadata JSON (params, deps, indexes) | Developer validates `[inferred]` flags |
| 5 | SP definitions must be in filesystem | Workflow blocked if SPs only exist in database | `Export-SpDefinitions.ps1` | Auto-detects exported files in `docs/sp-definitions/` | One-time export; commit to repo |

---

## Detailed Mitigations

### 1. Cannot Connect to Databases

**Without mitigation**: Claude Code cannot read SP source code at all. Workflow is dead on arrival.

**With PowerShell bridge**:

```powershell
# Run once (or when SPs change)
.\Export-SpDefinitions.ps1 -ServerInstance "localhost" -Database "AttractDB"
```

**What it produces**:
- `docs/sp-definitions/{schema}/{sp-name}.sql` — one file per SP with full CREATE PROCEDURE statement
- `docs/sp-definitions/manifest.json` — index with SP name, schema, param count, line count

**Claude Code integration**:
- `/sp-analyze` checks `docs/sp-definitions/` first
- `/sp-discover` cross-references definitions with .NET invocation points
- If definition is missing, Claude Code tells the developer exactly which script to run

**HITL effort**: ~5 minutes initial setup. Re-run after SP schema changes (infrequent — ~2 SPs/sprint).

**Automation potential**: Add `Export-SpDefinitions.ps1` to CI/CD pipeline to auto-export on `develop` branch builds. Eliminates manual re-runs entirely.

---

### 2. Cannot Execute SPs

**Without mitigation**: Claude Code cannot verify its analysis is correct. No way to compare before/after behavior.

**With PowerShell bridge**:

```powershell
# Before change
.\Test-SpChange.ps1 -SpName "DataSync.GetJobsForSync" -Parameters @{JobId=123} -Phase "before"

# After change
.\Test-SpChange.ps1 -SpName "DataSync.GetJobsForSync" -Parameters @{JobId=123} -Phase "after"
```

**What it produces**:
- `validation/{sp-name}/before_resultset_0.csv` — baseline result set
- `validation/{sp-name}/after_resultset_0.csv` — post-change result set
- `validation/{sp-name}/before_summary.json` — execution time, row count
- `validation/{sp-name}/after_summary.json` — execution time, row count
- `validation/{sp-name}/diff_report.md` — auto-generated comparison

**Claude Code integration**:
- `/sp-change-prep` generates the exact script with suggested parameter values
- After developer runs both phases, Claude Code reads `diff_report.md` and flags:
  - Row count changes (expected or unexpected)
  - Execution time delta
  - Result set structural changes

**HITL effort**: Developer provides realistic parameter values (~2 min). Runs script twice (~1 min each). Reviews Claude Code's diff analysis.

**Automation potential**: Create parameter presets per SP (saved in `validation/{sp-name}/params.json`). After first run, future validations can reuse saved parameters — further reducing HITL to just running the script.

---

### 3. Cannot Read Live Execution Plans

**Without mitigation**: Claude Code can suggest optimizations based on SQL structure but cannot see actual performance bottlenecks (missing indexes, table scans, estimated vs. actual row counts).

**With PowerShell bridge**:

```powershell
.\Export-ExecutionPlan.ps1 -SpName "DataSync.GetJobsForSync" -Parameters @{JobId=123}
```

**What it produces**:
- `execution-plans/{sp-name}_{timestamp}.sqlplan` — full XML plan (importable in SSMS)
- `execution-plans/{sp-name}_{timestamp}_summary.md` — parsed summary with:
  - Statement costs
  - Missing index recommendations (directly from SQL Server engine)
  - Warnings (implicit conversions, sort spills, etc.)

**Claude Code integration**:
- Claude Code reads the `_summary.md` and combines with SP structure analysis
- Can cross-reference missing index recommendations with actual table usage patterns
- Can validate whether suggested indexes align with the SP's JOIN/WHERE patterns

**HITL effort**: Developer runs script with realistic parameters (~2 min). Claude Code does the rest.

**Automation potential**: Capture execution plans as part of `Test-SpChange.ps1` (add `-CaptureExecutionPlan` flag). Before/after execution plans compared automatically.

---

### 4. Static Analysis Only (No Runtime Observation)

**Without mitigation**: Claude Code's analysis is based solely on reading SQL text. Dynamic SQL, conditional branches with runtime-dependent paths, and data-volume-dependent behavior are invisible.

**With PowerShell bridge (partial)**:

```powershell
# Metadata bridges the gap with database-level knowledge
.\Export-SpMetadata.ps1 -ServerInstance "localhost" -Database "AttractDB"

# Runtime stats show actual execution patterns
.\Get-SpStats.ps1 -ServerInstance "localhost" -Database "AttractDB"
```

**What it produces**:
- `sp-metadata.json` — parameter types, table dependencies (from `sys.sql_expression_dependencies`), cross-SP callers, index info
- `sp-runtime-stats.json` + `sp-runtime-stats.md` — execution count, avg/min/max duration, logical reads, CPU time, last execution

**Claude Code integration**:
- `/sp-analyze` auto-loads metadata JSON to validate its static analysis:
  - Cross-checks inferred table references against `sys.sql_expression_dependencies`
  - Uses runtime stats to prioritize analysis (focus on high-execution, high-duration SPs)
  - Uses index info to validate optimization suggestions
- Flags `[inferred]` for items that could only be confirmed at runtime:
  - Dynamic SQL execution paths
  - Conditional branches dependent on data values
  - Performance characteristics

**HITL effort**: Developer runs metadata export once (~5 min). Runtime stats export once (~2 min). Re-run periodically.

**Residual gap**: Dynamic SQL paths that build entirely different queries based on parameter values remain partially opaque. Claude Code can parse the string concatenation pattern but cannot predict all possible generated queries.

**Mitigation for residual gap**: Claude Code extracts the dynamic SQL template and lists all possible parameter combinations, letting the developer validate which paths are actually exercised.

---

### 5. SP Definitions Must Be in Filesystem

**Without mitigation**: If SPs only exist in the database (no `.sql` files in the repo), Claude Code has nothing to analyze.

**With PowerShell bridge**:

Same as Limitation #1 — `Export-SpDefinitions.ps1` solves this completely.

**Additional mitigation**: The Attract team already commits SP changes via Git PRs (confirmed in capture session). This means SP definitions likely already exist in the repo, possibly in a `db/` or `migrations/` folder.

**HITL effort**: Verify repo structure once. If SPs are in the repo, zero ongoing effort. If not, one-time export + commit.

---

## HITL Reduction Summary

| Activity | Without Workflow | With Workflow (no scripts) | With Workflow + Scripts |
|----------|-----------------|---------------------------|------------------------|
| Understanding SP logic | 1-3 days manual reading | ~30 min Claude Code analysis + review | ~30 min (same — scripts add validation data, not speed) |
| Blast radius assessment | Hours of grep + manual tracing | ~5 min Claude Code search | ~5 min (same — this is pure code analysis) |
| Documentation | Not done (0% coverage) | ~10 min per SP | ~10 min per SP (same) |
| Pre-change validation | Manual testing, no baseline | Checklist only (manual) | ~5 min script + Claude Code diff analysis |
| Execution plan analysis | SSMS manual inspection | Not possible | ~5 min script + Claude Code summary |
| Regression detection | Deploy and hope | Not possible | ~5 min before/after script |

**Total HITL per SP task**:
- **Without workflow**: 1-5 days
- **With workflow, no scripts**: ~1 hour (Claude Code analysis + manual validation)
- **With workflow + scripts**: ~1 hour + ~15 min scripted validation = **~1.25 hours**

The scripts don't significantly reduce time — they add **validation confidence** that was previously impossible without deploying to QA.

---

## CI/CD Integration (Future — Zero HITL)

For maximum automation, integrate scripts into the CI/CD pipeline:

```yaml
# Bamboo / GitHub Actions
on-develop-merge:
  - Export-SpDefinitions.ps1 → commit to repo (auto-update SP definitions)
  - Get-SpStats.ps1 → commit runtime stats snapshot

on-sp-change-detected:
  - Test-SpChange.ps1 -Phase "before" (against QA DB)
  - Apply SP change
  - Test-SpChange.ps1 -Phase "after"
  - Generate diff report → attach to PR as comment
```

This reduces the developer's HITL to: read Claude Code analysis + review auto-generated diff report.

---

## Checklist: Limitation Awareness for Champion

Share this with the champion before the Co-Implement session:

- [ ] **Claude Code reads files, not databases** — we'll export SP definitions first
- [ ] **Analysis is static** — dynamic SQL paths marked `[inferred]`, you validate
- [ ] **Performance analysis needs your help** — run the execution plan script, Claude Code interprets the results
- [ ] **Validation is scripted** — before/after comparison is automated, you provide parameter values
- [ ] **Documentation is auto-generated** — you review for accuracy, add business context
