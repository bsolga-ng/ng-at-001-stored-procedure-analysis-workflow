# Pre-Implementation Analysis: NG-AT-001

**Workflow**: Stored Procedure Analysis & Optimization
**Team**: Attract | **Champion**: Suresh Kumaravelu
**Analyzed**: 2026-03-16
**Analyst**: GVL Leader via /apex:pilot:implement:analyze-workflow

---

## Verdict

**Readiness**: READY WITH CAVEATS
**Risk Score**: Critical: 2, High: 3, Medium: 10, Low: 8
**Recommendation**: Fix the 2 Critical SQL injection issues in PowerShell scripts and resolve champion artifact block before co-implementation. The workflow design is solid — the issues are in execution details, not architecture.

---

## Structure Check

| Item                          | Status | Notes                                                                                   |
|-------------------------------|--------|-----------------------------------------------------------------------------------------|
| `/onboarding` command         | PASS   | Well-structured interactive walkthrough                                                 |
| Domain-prefixed commands      | PASS   | Prefix: `sp-` — consistent across all 5 commands                                       |
| README with quick start       | PASS   | Covers problem, solution, installation, commands, scripts, stack, principles            |
| Install script                | PASS   | `install.sh` present — but see finding below re: settings.local.json                    |
| Implementation plan           | PASS   | 6 phases, 355 lines, detailed tasks and risk register                                  |
| Permission model              | **FINDING** | Missing `Edit`/`Write` — commands can't save output files (see R-04 below)          |
| Templates                     | PASS   | `sp-analysis-template.md` — 14 sections, review checklist, comprehensive               |

---

## Capture Alignment

| Dimension                 | Status     | Notes                                                                                |
|---------------------------|------------|--------------------------------------------------------------------------------------|
| Pain points addressed     | ALIGNED    | All 4 capture friction signals mapped to specific commands                           |
| Tech stack match          | ALIGNED    | SQL Server + .NET 8 + ADO.NET/Dapper/EF + Angular — matches capture                 |
| Baseline metrics reflected| YES        | 4-5 / 3 / 1 day baselines preserved; targets align                                  |
| Missing info addressed    | YES        | Phase 0 maps exactly to capture "Missing Information" items                          |
| Scope appropriate         | MINOR CREEP| Optimization scripts (execution plans, stats) expand beyond core understanding/docs scope — position as Phase 2 |
| Data access pattern       | UNCONFIRMED| ADO.NET vs Dapper vs EF not yet confirmed — commands defensively support all three    |
| NG-AT-004 overlap         | GAP        | Pilot SP `DataSync.GetJobsForSync` is a sync SP — no guidance on how findings feed into future NG-AT-004 |

---

## Overlap Analysis

| Source       | Asset                           | Type          | Action                                                                  |
|--------------|---------------------------------|---------------|-------------------------------------------------------------------------|
| cc-templates | `microsoft-sql` MCP server      | Missed reuse  | If enabled, replaces most PowerShell scripts — document as Level 2 path |
| cc-templates | `architecture-diagram` (draw.io)| Complement    | Workflow uses Mermaid (appropriate for in-code docs) — no conflict      |
| WW catalog   | WW-MI-004 brownfield tracing    | Inherited     | Bidirectional tracing + `[inferred]` flags correctly borrowed           |
| WW catalog   | `[validated]` flag pattern       | Missed reuse  | Workflow uses `[inferred]` and `[?]` but not `[validated]` — add it    |
| Cross-team   | Learn (NG-LN-001 debugging)     | Parameterize  | SP analysis patterns reusable for Learn's .NET 4.8 debugging workflow   |
| Superpowers  | --                              | Independent   | No overlap — workflow is analysis-focused, not git/PR-focused           |

---

## Risk Register

### Critical

**R-01: SQL Injection in PowerShell Scripts**
- **What**: `Export-SpDefinitions.ps1` (lines 93-96) and `Export-SpMetadata.ps1` (lines 84-91, 147-148) interpolate user-supplied and DB-derived values directly into SQL strings: `"AND s.name = '$($parts[0])'"`.
- **Impact**: Malformed SP names could break queries; establishes unsafe pattern. While exploitation risk is low (inputs are SP names from the database), this fails security review.
- **Recommendation**: Refactor to use `SqlCommand.Parameters.AddWithValue()` — the same pattern already used correctly in `Test-SpChange.ps1` (lines 96-101).
- **Effort**: S (2-3 hours across all scripts)
- **When**: Before co-implementation

**R-02: Unsafe EXEC String Building in Export-ExecutionPlan.ps1**
- **What**: Lines 78-83 build an `EXEC` string with parameter values interpolated: `"'$($_.Value)'"`. This script **executes** against a real database.
- **Impact**: A parameter value containing `'; DROP TABLE --` would execute arbitrary SQL.
- **Recommendation**: Rewrite to use `CommandType.StoredProcedure` with `SqlParameter` objects (matching `Test-SpChange.ps1` pattern).
- **Effort**: S (1-2 hours)
- **When**: Before co-implementation

### High

**R-03: SQL Server MCP Opportunity Undocumented**
- **What**: cc-templates includes a `microsoft-sql` MCP server (disabled by default). If enabled, it gives Claude Code direct read access to SQL Server — eliminating most PowerShell bridge scripts.
- **Impact**: Workflow over-relies on manual PowerShell scripts when a simpler path may exist. Missing this makes the workflow harder to adopt than necessary.
- **Recommendation**: Add a "Level 2: MCP Integration" section to the playbook documenting the MCP alternative. Keep PowerShell scripts as fallback for environments where MCP is unavailable.
- **Effort**: S (1 hour to document)
- **When**: Before co-implementation

**R-04: Champion Artifacts Blocked 5+ Days**
- **What**: Phase 0 (artifact collection) has been blocked since 2026-03-11. No escalation timeline defined. All subsequent phases depend on these artifacts.
- **Impact**: Delays compound — each week of delay pushes the co-implement session and demo.
- **Recommendation**: Add escalation path: Day 3 → reminder; Day 5 → offer 15-min call; Day 7 → escalate to engagement lead. Current state: Day 5 — send the 15-min call offer now.
- **Effort**: S (15 minutes)
- **When**: Immediately

**R-05: No Azure AD Authentication in Scripts**
- **What**: All 5 PowerShell scripts support only Windows Integrated and SQL auth. NeoGov uses Azure SQL, which likely requires AAD auth.
- **Impact**: Blocks Phase 2 testing against Azure SQL databases.
- **Recommendation**: Add `-UseAzureAD` switch using `Azure.Identity` module or `Authentication=Active Directory Interactive` connection string option. Test early — don't discover this in the co-implement session.
- **Effort**: M (3-4 hours across all scripts)
- **When**: Before co-implementation

### Medium

**R-06: settings.local.json Missing Edit/Write Permissions**
- **What**: Permissions allow Read, Glob, Grep, Bash(git/pwsh) but not Edit or Write. Commands instruct Claude Code to write analysis files to `docs/sp-analysis/`.
- **Recommendation**: Add `Write` and `Edit` to allowed tools, scoped to `docs/` directory if possible.
- **Effort**: S
- **When**: Before co-implementation

**R-07: install.sh Doesn't Copy settings.local.json**
- **What**: Install script copies commands, templates, and scripts but not the permissions file. Target repo will lack needed permissions.
- **Recommendation**: Add settings.local.json merge logic (append workflow permissions without overwriting existing ones).
- **Effort**: S
- **When**: Before co-implementation

**R-08: Scripts Use Legacy System.Data.SqlClient**
- **What**: All scripts use `System.Data.SqlClient` which may not be available on PowerShell Core (`pwsh`) without the `SqlServer` module installed.
- **Recommendation**: Either switch to `Microsoft.Data.SqlClient` or document `Install-Module SqlServer` as a prerequisite.
- **Effort**: S (if documenting) / M (if switching)
- **When**: Before co-implementation

**R-09: Context Window Risk for Large SPs**
- **What**: No guidance on handling SPs with 2000+ lines plus full codebase scanning. Could exceed effective context.
- **Recommendation**: Add a note to `/sp-analyze` recommending `--blast-only` or section-by-section analysis for very large SPs. Document the "SP too large" escape hatch.
- **Effort**: S
- **When**: Before demo

**R-10: CLR Functions and Linked Servers Not Detected**
- **What**: `sp-analyze` has no detection for `EXTERNAL NAME` (CLR) or `[LinkedServer].[DB].[Schema].[Table]` patterns. Analysis will be silently incomplete.
- **Recommendation**: Add detection patterns and flag as `[?] CLR/Linked Server detected — manual review required`.
- **Effort**: S
- **When**: Before replication

**R-11: Complex SP Time Target May Be Optimistic**
- **What**: Capture target: 1 day. Implementation plan: 1-2 days. Understanding is ~50% of total fix time; the workflow doesn't automate the actual fix, test, or PR.
- **Recommendation**: Use "1-2 days" consistently. Frame the metric as "time to understand + document + prepare change" not "time to complete the fix."
- **Effort**: S (wording only)
- **When**: Before demo

**R-12: Self-Report Only Measurement**
- **What**: All time metrics rely on developer self-report. No objective tracking (JIRA, git timestamps) proposed.
- **Recommendation**: Supplement with git commit timestamps (first commit on SP-related branch to PR merge) for at least the pilot SPs. This provides an objective baseline vs. AI-assisted comparison.
- **Effort**: S
- **When**: Before Phase 5 measurement

**R-13: NG-AT-004 Scope Boundary Undefined**
- **What**: Pilot SP `DataSync.GetJobsForSync` is a sync SP. NG-AT-004 (Cross-App Sync) is a future capture candidate. No guidance on how NG-AT-001 analysis outputs feed forward.
- **Recommendation**: Add a note to the implementation plan that NG-AT-001 analysis artifacts for sync SPs should be tagged for future NG-AT-004 reuse.
- **Effort**: S
- **When**: Before replication

**R-14: Dry Run Depends on Real SP (Blocked)**
- **What**: Phase 3 requires a real SP task but artifacts aren't available. No synthetic/mock data fallback documented.
- **Recommendation**: Create a synthetic SP + .NET stub for dry run purposes. 50-line SP with 2-3 tables, one dynamic SQL path, 3 .NET call sites. Validates the entire workflow without champion dependency.
- **Effort**: M (2-3 hours)
- **When**: Immediately (unblocks Phase 3 while waiting for artifacts)

**R-15: Single Champion Dependency**
- **What**: Suresh is sole champion for all Attract workflows. No backup identified.
- **Recommendation**: Identify one of the other 3 SP developers as backup champion during co-implement session.
- **Effort**: S
- **When**: During co-implementation

### Low

**R-16**: Missing `docs/powershell-scripts.md` referenced in README — create or remove reference
**R-17**: `--refresh` flag inconsistency between README and sp-analyze — align docs
**R-18**: No `[validated]` flag in lifecycle — add to complete the `[inferred]` → `[validated]` progression
**R-19**: Mermaid diagram syntax not auto-validated — manual check only
**R-20**: Blast radius may miss SPs called via generic repository base class patterns
**R-21**: `Test-SpChange.ps1` 300s timeout may be insufficient for large sync SPs — make configurable
**R-22**: `Export-ExecutionPlan.ps1` requires `SHOWPLAN` permission — not documented as prerequisite
**R-23**: Batch `/sp-document --batch` has no session management guidance for large runs

---

## Recommendations

### Must Fix (before co-implementation) — 7 items

1. **R-01 + R-02**: Refactor all PowerShell scripts to use parameterized queries. Use `Test-SpChange.ps1` as the reference pattern. (~3-4 hours)
2. **R-04**: Send Suresh the 15-min call offer today (Day 5 of block). Define escalation: Day 7 → engagement lead.
3. **R-05**: Add Azure AD auth support to all scripts. Test against Azure SQL before co-implement.
4. **R-06**: Add `Write` and `Edit` to `settings.local.json` allowed tools.
5. **R-07**: Update `install.sh` to merge `settings.local.json`.
6. **R-08**: Document `SqlServer` module prerequisite or switch to `Microsoft.Data.SqlClient`.
7. **R-03**: Add MCP alternative documentation to playbook.

### Should Fix (before demo) — 3 items

1. **R-09**: Add large-SP guidance to `/sp-analyze`.
2. **R-11**: Align time targets — use "1-2 days" consistently, clarify metric scope.
3. **R-14**: Create synthetic SP + .NET stub for dry run (also unblocks Phase 3 immediately).

### Consider (before replication) — 5 items

1. **R-10**: Add CLR function and linked server detection patterns.
2. **R-12**: Supplement self-report with git timestamp measurement.
3. **R-13**: Tag sync SP analysis outputs for NG-AT-004 reuse.
4. **R-18**: Add `[validated]` flag to complete inference lifecycle.
5. **R-15**: Identify backup champion during co-implement session.

### Validate with Champion

1. Which data access pattern does the team use — ADO.NET, Dapper, EF, or mixed?
2. Does the team have Azure AD auth for their local/dev SQL Server connections?
3. Is `SHOWPLAN` permission granted to developer accounts?
4. Are there SPs with CLR functions or linked server references?
5. What is the largest SP by line count? (Context window planning)

---

## Next Steps

1. [ ] Fix Critical R-01 + R-02 (SQL injection in PowerShell scripts)
2. [ ] Send champion artifact follow-up (R-04) — offer 15-min call
3. [ ] Create synthetic SP + stub for dry run (R-14) — unblocks Phase 3
4. [ ] Add Edit/Write permissions to settings.local.json (R-06)
5. [ ] Update install.sh to merge settings (R-07)
6. [ ] Add Azure AD auth support (R-05)
7. [ ] Document MCP alternative path in playbook (R-03)
