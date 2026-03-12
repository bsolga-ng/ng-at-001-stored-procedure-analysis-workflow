# Implementation Plan: NG-AT-001 SP Analysis Workflow

**Workflow**: Stored Procedure Analysis & Optimization
**Team**: Attract (AT)
**Champion**: Suresh Kumaravelu
**GVL Leaders**: Bogdan Solga, Oleksii Popov
**Created**: 2026-03-11
**Status**: Phase 1 blocked on champion artifacts

---

## Phase 0: Artifact Collection (Blocked — Waiting on Champion)

**Goal**: Collect the minimum artifacts needed to validate and test the workflow.

### Tasks

| # | Task | Owner | Status | Dependency |
|---|------|-------|--------|------------|
| 0.1 | Request top 3 most-used SP names from Suresh | Bogdan | Pending | — |
| 0.2 | Request SP source code for `DataSync.GetJobsForSync` + 2 others | Bogdan | Pending | 0.1 |
| 0.3 | Confirm repo structure: which of the 3 repos contains SP definitions and .NET data access code | Bogdan | Pending | — |
| 0.4 | Confirm data access pattern: ADO.NET, Dapper, or EF for SP calls | Bogdan | Pending | 0.3 |
| 0.5 | Get local DB connection string format (for PowerShell script testing) | Bogdan | Pending | — |
| 0.6 | Request a recent SP task example (bug fix or optimization Suresh worked on) — what he looked at, in what order | Bogdan | Pending | — |

### Artifact Request Message (copy-paste ready)

> Hi Suresh,
>
> Following up on our Capture session — we're building the AI-assisted SP analysis workflow we discussed. To validate it against your actual codebase, I need a few things:
>
> 1. **Top 3 SP names** you work with most frequently (you mentioned `DataSync.GetJobsForSync` — which other 2?)
> 2. **SP source code** — either point me to the repo path where `.sql` files live, or share the source for those 3 SPs
> 3. **Which repository** (of your 3) contains the SP definitions and the .NET code that calls them?
> 4. **How does your .NET code call SPs?** — is it ADO.NET `SqlCommand`, Dapper `.Query()`, Entity Framework `.FromSqlRaw()`, or something else?
> 5. **Local DB connection** — what format do you use to connect to your local dev database? (for the PowerShell validation scripts)
> 6. **A recent SP task** — can you briefly describe a recent bug fix or optimization you did on an SP? (what you looked at, in what order, how long it took)
>
> If it's easier, happy to jump on a 15-min call to walk through these together.
>
> Thanks,
> Bogdan

### Exit Criteria

- [ ] 3 SP names confirmed
- [ ] SP source code available (in repo or shared)
- [ ] Repo structure understood (which repo, which folders)
- [ ] Data access pattern confirmed (ADO.NET / Dapper / EF)
- [ ] Local DB access confirmed for PowerShell scripts

---

## Phase 1: Validate Workflow Against Real Codebase

**Goal**: Verify that the Claude Code commands and PowerShell scripts work with the Attract team's actual code and database structure.

**Depends on**: Phase 0 complete (artifacts received)

### Tasks

| # | Task | Ref | Verification |
|---|------|-----|-------------|
| 1.1 | Clone the Attract repo(s) locally | — | Repo accessible, can browse .NET code |
| 1.2 | Run `/sp-discover` against the .NET codebase | `.claude/commands/sp-discover.md` | Registry generated at `docs/sp-analysis/_index.md` with SP count matching Suresh's estimate (~30+ used, 100+ total) |
| 1.3 | Verify SP name detection patterns match Attract's data access layer | `sp-discover.md` lines for ADO.NET/Dapper/EF patterns | All 3 pilot SPs found. If not: update search patterns for their specific access layer |
| 1.4 | Run `/sp-analyze DataSync.GetJobsForSync` | `.claude/commands/sp-analyze.md` | Analysis doc generated with parameters, tables, logic flow, blast radius |
| 1.5 | Validate analysis accuracy: compare Claude Code's output against Suresh's description from the capture session | `2026-03-10-capture-analysis.md` NG-AT-001 card | Parameter list correct, invocation points found, dynamic SQL flagged if present |
| 1.6 | Run `/sp-blast-radius DataSync.GetJobsForSync` | `.claude/commands/sp-blast-radius.md` | Invocation map generated with .NET call chains traced to HTTP endpoints |
| 1.7 | Run `/sp-analyze` on the 2nd and 3rd pilot SPs | — | All three SPs documented, patterns validated across different SP types |

### Anti-Pattern Guards

- Do NOT assume SP definitions are in a specific folder — discover by scanning
- Do NOT hardcode ADO.NET patterns — confirm which data access layer the team uses first
- Do NOT skip blast radius validation — this is the highest-value output

### Quality Gate

| Criterion | Pass |
|-----------|------|
| `/sp-discover` finds all 3 pilot SPs | [ ] |
| `/sp-analyze` produces accurate analysis for all 3 | [ ] |
| Blast radius correctly identifies .NET callers | [ ] |
| Mermaid diagrams render | [ ] |
| `[inferred]` items are reasonable (not hallucinated) | [ ] |
| Suresh confirms analysis is directionally correct | [ ] |

---

## Phase 2: Test PowerShell Scripts Against Local DB

**Goal**: Validate all 5 PowerShell scripts produce correct, usable output from the Attract team's Azure SQL / local DB.

**Depends on**: Phase 0.5 (local DB connection string)

### Tasks

| # | Task | Script | Verification |
|---|------|--------|-------------|
| 2.1 | Test `Export-SpDefinitions.ps1` — export all SPs | `scripts/powershell/Export-SpDefinitions.ps1` | `.sql` files generated in `docs/sp-definitions/`, manifest.json created, SP count matches |
| 2.2 | Test `Export-SpDefinitions.ps1` — export single SP | Same, with `-SpName "DataSync.GetJobsForSync"` | Single file generated, content matches what's in the database |
| 2.3 | Test `Export-SpMetadata.ps1` — export metadata | `scripts/powershell/Export-SpMetadata.ps1` | `sp-metadata.json` generated with parameters, dependencies, indexes for each SP |
| 2.4 | Test `Get-SpStats.ps1` — runtime stats | `scripts/powershell/Get-SpStats.ps1` | `sp-runtime-stats.md` generated with execution counts and avg durations |
| 2.5 | Test `Export-ExecutionPlan.ps1` — execution plan | `scripts/powershell/Export-ExecutionPlan.ps1` | `.sqlplan` XML and `_summary.md` generated, missing index recommendations captured if any |
| 2.6 | Test `Test-SpChange.ps1` — before/after flow | `scripts/powershell/Test-SpChange.ps1` | Run with `-Phase "before"` and `-Phase "after"` (same SP, no change), diff report shows IDENTICAL |
| 2.7 | Fix any connection issues: Azure SQL auth (AAD vs SQL auth), firewall rules, PowerShell module requirements | — | All 5 scripts execute without errors |

### Known Risks

| Risk | Mitigation |
|------|-----------|
| Azure SQL uses AAD auth, not SQL auth | Scripts support `-Credential` param; may need `Az.Sql` module or connection string adaptation for AAD |
| `sys.dm_exec_procedure_stats` may be empty on local DB (no cached plans) | Run against QA/staging DB for stats, or accept empty stats on local |
| Some SPs may use CLR functions or linked servers | Flag these as unsupported edge cases; document in limitations |
| PowerShell Core (`pwsh`) not installed on dev machines | Test with Windows PowerShell 5.1 fallback; document installation if needed |

### Quality Gate

| Criterion | Pass |
|-----------|------|
| All 5 scripts execute without errors | [ ] |
| Output files are well-formed (valid JSON, valid SQL, valid Markdown) | [ ] |
| Exported SP definitions match database content | [ ] |
| Metadata correctly lists parameters and dependencies | [ ] |
| Test-SpChange diff report generates correctly | [ ] |

---

## Phase 3: End-to-End Dry Run

**Goal**: Execute the complete workflow (discover → analyze → change-prep → validate) on one real SP task, without Suresh. Measure GVL time and identify friction.

**Depends on**: Phase 1 + Phase 2 complete

### Tasks

| # | Task | Verification |
|---|------|-------------|
| 3.1 | Pick a real (or simulated) SP task — a bug report or optimization request from the backlog | Task identified, SP name known |
| 3.2 | Run full workflow: `/sp-discover` → `/sp-analyze {sp}` → `/sp-change-prep {sp}` | All outputs generated |
| 3.3 | Run PowerShell: `Export-SpDefinitions` → `Export-SpMetadata` → `Test-SpChange -Phase before` | Baseline captured |
| 3.4 | Make a minor SP change (or simulate one) | Change applied to .sql file |
| 3.5 | Run `Test-SpChange -Phase after` and review diff | Diff report generated, shows expected delta |
| 3.6 | Run `/sp-document {sp} --refresh` | Docs updated |
| 3.7 | **Time the entire process** — from "assigned task" to "documented and validated" | Total time recorded |
| 3.8 | Document friction points: confusing command output, missing information, incorrect analysis, template issues | Friction list created |
| 3.9 | Fix identified issues in commands/templates/scripts | Issues resolved |

### Metrics to Capture

| Metric | Measurement |
|--------|------------|
| Total time: task assignment → documented | Stopwatch |
| Time in Claude Code analysis | Stopwatch per command |
| Time in PowerShell scripts | Stopwatch per script |
| Time in manual review (HITL) | Stopwatch |
| Number of `[inferred]` items that were correct | Count correct / total |
| Number of `[inferred]` items that were wrong | Count wrong / total |
| Blast radius: found vs. actual (if verifiable) | Count |

### Quality Gate

| Criterion | Pass |
|-----------|------|
| End-to-end workflow completed without blocking errors | [ ] |
| Total time under 2 hours (target: ~1.25 hours) | [ ] |
| Analysis accuracy >70% (`[inferred]` items mostly correct) | [ ] |
| Friction points identified and fixed | [ ] |

---

## Phase 4: Co-Implement Session with Suresh

**Goal**: Champion learns and executes the workflow on a real SP task. Measure time, collect feedback, validate metrics.

**Depends on**: Phase 3 complete (workflow validated, friction fixed)

### Pre-Session

| # | Task | Owner |
|---|------|-------|
| 4.1 | Install workflow commands in Attract repo: `./scripts/install.sh /path/to/attract-repo` | Bogdan |
| 4.2 | Pre-run `/sp-discover` to build registry (so session focuses on analysis) | Bogdan |
| 4.3 | Pre-run PowerShell exports (definitions, metadata) if not already in repo | Bogdan |
| 4.4 | Prepare demo script: 3-step walkthrough showing `/sp-analyze`, `/sp-blast-radius`, `/sp-change-prep` | Bogdan |
| 4.5 | Identify Suresh's current/upcoming SP task as the pilot subject | Bogdan + Suresh |
| 4.6 | Schedule 1.5h Co-Implement session | Bogdan |

### Session Agenda (~90 min)

| Time | Activity | Who |
|------|----------|-----|
| 0-10 min | **Intro**: Show workflow overview, explain what AI can/can't do, set expectations | Bogdan |
| 10-25 min | **Demo**: Run `/sp-analyze` on a known SP, walk through output | Bogdan (Suresh observes) |
| 25-40 min | **Hands-on**: Suresh runs `/sp-analyze` on his current task SP | Suresh (Bogdan assists) |
| 40-55 min | **Blast radius**: Suresh runs `/sp-blast-radius`, validates results | Suresh |
| 55-70 min | **Change prep**: Run `/sp-change-prep`, generate validation scripts | Suresh |
| 70-80 min | **PowerShell**: Demo `Test-SpChange.ps1` for before/after validation | Bogdan |
| 80-90 min | **Feedback + next steps**: What worked, what didn't, adoption plan | Both |

### Metrics to Capture During Session

| Metric | How |
|--------|-----|
| Time to understand SP with AI | Stopwatch: start `/sp-analyze` to "I understand this SP" |
| Time to assess blast radius | Stopwatch: start `/sp-blast-radius` to "I know what's affected" |
| Champion confidence (1-5) | Ask Suresh after each step |
| Accuracy of AI analysis | Suresh validates against his knowledge |
| Friction points | Note what confused or blocked Suresh |

### Quality Gate

| Criterion | Pass |
|-----------|------|
| Suresh successfully runs `/sp-analyze` independently | [ ] |
| Suresh confirms analysis is accurate for his SP | [ ] |
| Blast radius correctly identifies callers Suresh knows about | [ ] |
| Suresh can articulate the workflow to a teammate | [ ] |
| Time with AI < baseline time without AI | [ ] |
| Champion confidence >= 3/5 | [ ] |

---

## Phase 5: Measure & Package Results

**Goal**: Capture before/after metrics for the breakthrough story. Package workflow for reuse.

**Depends on**: Phase 4 complete + Suresh uses workflow on 2-3 real SP tasks

### Tasks

| # | Task | Owner | Verification |
|---|------|-------|-------------|
| 5.1 | Suresh uses workflow on 2-3 real SP tasks over the next sprint | Suresh | Tasks completed, times recorded |
| 5.2 | Collect before/after metrics from Suresh | Bogdan | Data for 3+ SP tasks |
| 5.3 | Calculate average time reduction: baseline vs. with-workflow | Bogdan | % improvement calculated |
| 5.4 | Count documentation generated: how many SPs now documented | Bogdan | Coverage number |
| 5.5 | Run `/apex:pilot:demo:prepare` — verify deliverables for Demo session | Bogdan | Checklist complete |
| 5.6 | Write breakthrough story: `/apex:pilot:package` | Bogdan | Story generated |

### Expected Metrics

| Metric | Baseline | Expected With Workflow | Measurement |
|--------|----------|----------------------|-------------|
| Complex SP fix time | 4-5 days | 1-2 days | Self-report |
| Moderate SP fix time | 3 days | 1 day | Self-report |
| Simple SP fix time | 1 day | 2-4 hours | Self-report |
| SP documentation coverage | 0% | Top 10-30 SPs (10-30%) | Artifact count |
| Blast radius assessment time | Hours (manual grep) | 5 min | Stopwatch |
| Dev-days saved per sprint | 0 | ~3 dev-days | Calculation |

---

## Phase 6: Replication & Expansion

**Goal**: Package workflow for Learn and PSS Vitals teams. Adapt for their tech stacks.

**Depends on**: Phase 5 complete (metrics validated)

### Tasks

| # | Task | Owner | Verification |
|---|------|-------|-------------|
| 6.1 | Review workflow portability: identify Attract-specific assumptions | Bogdan | List of hardcoded assumptions |
| 6.2 | Parameterize any team-specific configuration (DB names, repo paths, data access patterns) | Bogdan | Config file or command flags |
| 6.3 | Check Learn team assessment for SP-related signals | Bogdan | Applicability assessment |
| 6.4 | Check PSS Vitals assessment for SP-related signals | Bogdan | Applicability assessment |
| 6.5 | If applicable: adapt install script and commands for other team's tech stack | Bogdan | Commands work in different .NET project structure |
| 6.6 | Roll out to second team (if SP signals exist) | Bogdan + team champion | Workflow installed and tested |
| 6.7 | Update workflow-catalog.md with NG-AT-001 entry | Bogdan | Catalog updated with metrics and transferability |

### Transferability Assessment

| Dimension | Attract (current) | Other teams (potential) |
|-----------|-------------------|------------------------|
| Database | Azure SQL Server | Likely same (shared infrastructure) |
| Backend | .NET 8 | Likely .NET (NeoGov standard) |
| Data access | TBD (Dapper/ADO.NET/EF) | May differ per team |
| SP complexity | High (legacy Talent Lyft) | Varies |
| CI/CD | Bamboo | Likely shared |

**Expected transferability**: High — NeoGov teams share Azure SQL infrastructure and .NET backend. Primary adaptation: data access pattern detection and SP naming conventions.

---

## Limitations Mitigation Checklist

### Pre-Session Checklist (share with champion)

- [ ] **Claude Code reads files, not databases** — SP definitions exported via PowerShell
- [ ] **Analysis is static** — dynamic SQL paths marked `[inferred]`, champion validates
- [ ] **Performance analysis needs script output** — execution plan exported from SSMS/script
- [ ] **Validation is scripted** — before/after comparison automated, champion provides parameter values
- [ ] **Documentation is auto-generated** — champion reviews for accuracy, adds business context

### Script Readiness Checklist

| Script | Tested | Works With Local DB | Works With Azure SQL | Notes |
|--------|--------|--------------------|--------------------|-------|
| `Export-SpDefinitions.ps1` | [ ] | [ ] | [ ] | |
| `Export-SpMetadata.ps1` | [ ] | [ ] | [ ] | |
| `Export-ExecutionPlan.ps1` | [ ] | [ ] | [ ] | |
| `Test-SpChange.ps1` | [ ] | [ ] | [ ] | |
| `Get-SpStats.ps1` | [ ] | [ ] | [ ] | DMV may be empty on local |

### Limitation-Specific Mitigations Status

| # | Limitation | Mitigation | Status | Residual Risk |
|---|-----------|-----------|--------|---------------|
| 1 | No DB connection | `Export-SpDefinitions.ps1` exports to files | [ ] Tested | Re-run needed when SPs change (~2/sprint) |
| 2 | Can't execute SPs | `Test-SpChange.ps1` captures before/after | [ ] Tested | Developer must provide realistic parameter values |
| 3 | No live execution plans | `Export-ExecutionPlan.ps1` captures estimated plan | [ ] Tested | Estimated plan may differ from actual (parameter sniffing) |
| 4 | Static analysis only | `Export-SpMetadata.ps1` + `Get-SpStats.ps1` bridge | [ ] Tested | Dynamic SQL paths remain partially opaque |
| 5 | SPs must be in filesystem | `Export-SpDefinitions.ps1` or verify repo has them | [ ] Tested | One-time setup |

### CI/CD Automation Plan (Phase 6+)

| Trigger | Script | Output | Eliminates HITL |
|---------|--------|--------|----------------|
| Develop branch merge | `Export-SpDefinitions.ps1` | Auto-updated SP definitions in repo | Manual re-export |
| Develop branch merge | `Get-SpStats.ps1` | Runtime stats snapshot | Manual stats collection |
| PR with `.sql` changes | `Test-SpChange.ps1 -Phase before/after` | Diff report as PR comment | Manual before/after comparison |
| Weekly schedule | `/sp-document --coverage` | Documentation coverage report | Manual coverage tracking |

---

## Timeline

| Week | Phase | Key Milestone |
|------|-------|---------------|
| **W1** (current) | Phase 0 | Artifacts requested from Suresh |
| **W2** | Phase 0 → 1 | Artifacts received; validate workflow against real codebase |
| **W2** | Phase 2 | PowerShell scripts tested against local DB |
| **W3** | Phase 3 | End-to-end dry run completed |
| **W3** | Phase 4 | Co-implement session with Suresh |
| **W4-5** | Phase 5 | Suresh uses workflow on 2-3 real tasks; metrics collected |
| **W5** | Phase 5 | Breakthrough story written; Demo session |
| **W6+** | Phase 6 | Replication to other teams (if applicable) |

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Suresh delays providing artifacts | Medium | Blocks all phases | Send async questions; offer 15-min call alternative |
| SPs not in Git repo (only in database) | Low | Extra setup step | `Export-SpDefinitions.ps1` solves this completely |
| .NET data access pattern not covered by search patterns | Medium | `/sp-discover` misses SPs | Phase 1.3 validates; add custom patterns if needed |
| PowerShell scripts fail on Azure SQL auth | Medium | Blocks Phase 2 | Test early; support AAD auth, connection string variants |
| Analysis accuracy <70% | Low | Undermines champion confidence | Phase 3 dry run catches this before co-implement session |
| Champion too busy for 90-min co-implement | Medium | Delays Phase 4 | Offer 2x 45-min sessions; pre-record demo as alternative |
| Dynamic SQL makes analysis unreliable | Medium | Reduces value for some SPs | Flag clearly; focus pilot on SPs with static SQL first |
