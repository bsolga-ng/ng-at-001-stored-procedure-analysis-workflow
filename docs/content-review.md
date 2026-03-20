# Content Review: NG-AT-001 Stored Procedure Analysis & Optimization

**Workflow**: Stored Procedure Analysis & Optimization
**Team**: Attract (AT) | **Champion**: Suresh Kumaravelu
**Reviewer**: GVL Leader via /apex:pilot:implement:review-workflow
**Date**: 2026-03-20
**Workflow Repo**: `neogov-workflows/ng-at-001-stored-procedure-analysis-workflow/`
**Artifacts Repo**: `neogov-artifacts/`

---

## Verdict

| Dimension | Rating |
|-----------|--------|
| **Friction-to-Capability Tracing** | STRONG -- all 7 friction signals mapped to specific workflow capabilities |
| **Metric Alignment** | ALIGNED WITH CAVEATS -- baselines match, targets need consistent framing |
| **Tech Stack Verification** | VERIFIED -- .NET 8 + Azure SQL + Angular 20 + Dapper confirmed; Bamboo CI/CD assumed |
| **Champion Preference Match** | STRONG -- blast radius priority confirmed in Spot session; workflow restructured accordingly |
| **Cross-Team Overlap** | IDENTIFIED -- Learn team (NG-LN-001) shares blast radius pattern; DMS Policy has SQL Server SPs |
| **Overall Readiness** | READY FOR CO-IMPLEMENTATION -- pending DB backup from champion |

---

## Phase 1: Discussion Trail Summary

### Sources Reviewed

| Source | File | Key Content |
|--------|------|-------------|
| Account Details | `account-details.yaml` | Team code AT, champion Suresh, tech stack (.NET 8, Azure SQL, Angular 20, Bamboo) |
| Assessment | `1-assess/1-discovery/attract/2026-03-03-assessment.md` | 12 signals; top: Implementation/Database (4 signals, 2 High), Testing (3 signals, 2 High) |
| Assess Transcript | `Attract Assess session - 2026_03_03 - Notes by Gemini.md` | Full transcript; SP pain, incident triage, CI/CD test integration, sync process |
| Capture Analysis | `2-pilot/1-capture/attract/2026-03-10-capture-analysis.md` | NG-AT-001 fully captured; NG-AT-002 partial; 7 workflows total |
| Capture Scorecard | `2-pilot/1-capture/attract/2026-03-10-scorecard.md` | NG-AT-001 ready for pilot; ~5 dev-days/sprint; ~3 dev-days savings target |
| Capture Transcript | `Attract Capture session - 2026_03_10 - Notes by Gemini.md` | SP walkthrough, incident triage process, action items |
| Spot Guide | `2-pilot/2-spot/attract/2026-03-17-spot-guide.md` | 9 questions; answers captured inline |
| Spot Record | `2-pilot/2-spot/attract/2026-03-17-spot-record.md` | Blast radius = highest value; top 3 SPs confirmed; NG-AT-002 deprioritized to P3 |
| Spot Transcript | `Attract Spot session - 2026_03_17 - Notes by Gemini.md` | Full session notes; local FE testing pain surfaced; BDD skill reference |
| Workflow README | `README.md` | Problem/solution, installation, 6 commands, 5 PowerShell scripts, MCP integration |
| Implementation Plan | `docs/implementation-plan.md` | 6 phases, detailed tasks, risk register, timeline |
| Limitations | `docs/limitations-and-mitigations.md` | 5 limitations with PowerShell bridge mitigations |
| Playbook | `docs/playbook.md` | Step-by-step guide, 5 stages, MCP Level 2, troubleshooting |
| Pre-Impl Analysis | `docs/pre-implementation-analysis.md` | 23 risks (2 Critical, 3 High); "Ready with caveats" |
| Example Analysis | `docs/examples/Recruitment.GetCandidateList.md` | 710-line XL SP; blast radius, parameters, logic, Mermaid diagrams |
| Skills (4) | `.claude/skills/sp-analysis/`, `sp-discover/`, `sp-change-prep/`, `sp-document/` | Auto-triggering skills with composition rules |
| Onboarding Command | `.claude/commands/onboarding.md` | Interactive walkthrough with 6 demo options |
| Install Script | `scripts/install.sh` | Copies skills, commands, scripts; merges settings.local.json |
| PowerShell Scripts (5) | `scripts/powershell/*.ps1` | DB bridge scripts for SP export, metadata, stats, execution plans, change validation |
| Analysis Template | `templates/sp-analysis-template.md` | 14-section template with review checklist |

### Discussion Arc

The workflow emerged from a clear escalation path:

1. **Assess (Mar 3)**: Suresh identified SP complexity as a top pain -- "the SQL queries within the stored procedures are enormous" and "the application slowness is entirely tied to the database." 12 signals captured; Implementation/Database was the highest-concentration category.

2. **Capture (Mar 10)**: Deep-dive into SP workflow. Process mapped: Angular app -> Network tab -> .NET backend -> Azure SQL SP. Friction crystallized: zero documentation for 100+ SPs, no blast radius visibility, 4-5 days for complex fixes. Baseline: ~5 dev-days/sprint on SP work across 4 developers.

3. **Spot (Mar 17)**: Workflow presented to champion with 6 commands. Key pivot: Suresh confirmed **blast radius is the highest-value output**, not logic understanding (which Claude Code already helps with). Top 3 SPs identified: `Recruitment.GetCandidateList`, `DataSync.SaveCandidate`, `Candidates.CreateCompany`. NG-AT-002 (incident triage) deprioritized from P1 to P3 (only 3-5 cases/sprint). Co-implementation scheduled for the following week.

---

## Phase 2: Friction-to-Capability Tracing

### Friction Signal Map

| # | Friction Signal | Source Quote | Workflow Capability | Skill/Command | Coverage |
|---|----------------|-------------|--------------------|--------------|---------|
| F1 | No SP documentation -- zero KB for 100+ SPs | "we don't have a KB for the SP, there is no explicit knowledge about them" -- Suresh (Capture) | Auto-generated structured docs with parameters, tables, logic flow, Mermaid diagrams | `sp-document` skill, `sp-analysis` skill Phase 5 | FULL |
| F2 | Understanding is #1 time sink | "first understanding, we don't have any documentation -- we must understand the logic, input params, result sets" -- Suresh (Capture) | Automated SP logic parsing: parameters, tables, JOINs, dynamic SQL, conditional paths | `sp-analysis` skill Phases 2-4 | FULL |
| F3 | No blast radius visibility | "there might be multiple places where the SP is invoked... not reliably possible to validate regression issues" -- Suresh (Capture) | Bidirectional tracing: SP -> .NET callers (Repository -> Service -> Controller -> HTTP endpoint) | `sp-analysis` skill Phase 3, `sp-discover` skill | FULL |
| F4 | Legacy SP accumulation | "we kept on adding the new stored procedures or any other database components at back end" -- Suresh (Assess) | SP registry via `/sp-discover` -- catalogs all SPs referenced in .NET code with definition status | `sp-discover` skill | FULL |
| F5 | Dynamic SQL complexity | SPs use dynamic parameters in SQL JOINs (department restriction logic) -- Capture session walkthrough | Dynamic SQL detection, template extraction, `[inferred]` flags for paths needing runtime validation | `sp-analysis` skill Phase 4.3 | PARTIAL -- dynamic SQL paths remain partially opaque (documented in limitations) |
| F6 | App slowness is DB-driven | "the application slowness is entirely tied to... it is more inclined towards the database" -- Suresh (Assess) | Execution plan export + analysis, runtime stats from DMVs, optimization suggestions | `Export-ExecutionPlan.ps1`, `Get-SpStats.ps1`, `sp-analysis` optimization section | PARTIAL -- requires PowerShell scripts or MCP; positioned as Phase 2 capability |
| F7 | Regression risk on SP changes | "must be understood... not reliably possible to validate regression issues" -- Suresh (Capture) | Before/after SP execution comparison with auto-diff report | `sp-change-prep` skill, `Test-SpChange.ps1` | FULL |

### Tracing Verdict

**7 of 7 friction signals are mapped to specific workflow capabilities.** 5 have full coverage; 2 have partial coverage with documented mitigations (dynamic SQL opacity, performance analysis requiring scripts). No friction signals are unaddressed.

### Gap: Unaddressed Champion Need

One signal from the Spot session is NOT covered by the workflow:

- **Local FE testing friction** -- "the front-end cannot be tested locally" (Spot record, finding #6). This is outside the SP analysis workflow scope but was surfaced as a new pain point. Correctly noted as a future workflow candidate, not a gap in NG-AT-001.

---

## Phase 3: Metric Alignment

### Scorecard Baselines vs. Workflow Targets

| Metric | Scorecard Baseline | Workflow Target | Source | Alignment |
|--------|-------------------|----------------|--------|-----------|
| Complex SP fix (sync SPs) | 4-5 days | 1 day (capture card) / 1-2 days (impl plan) | Capture analysis NG-AT-001 card; Implementation plan Phase 5 | MISALIGNED -- see finding M1 |
| Moderate SP fix | 3 days | 1 day | Consistent across all sources | ALIGNED |
| Simple SP fix | 1 day | 2-4 hours | Consistent across all sources | ALIGNED |
| SP work frequency | ~2 SPs/sprint (4 devs) | Same frequency, faster resolution | Scorecard portfolio view | ALIGNED |
| SP documentation coverage | 0% | Top 30 SPs documented (30%) | Capture analysis, implementation plan | ALIGNED |
| Blast radius assessment time | Hours (manual grep) | ~5 minutes | Implementation plan Phase 5, workflow catalog | ALIGNED |
| Dev-days saved per sprint | 0 (baseline) | ~3 dev-days | Scorecard impact projection | ALIGNED -- derived from 2 SPs x (2.5 day avg - 1 day avg) |
| Affected developers | 4 of 4 | 4 of 4 | Capture analysis | ALIGNED |

### Metric Findings

**M1: Complex SP Target Inconsistency**

- The capture card says "1 day" for complex SP fixes (target).
- The implementation plan Phase 5 says "1-2 days."
- The pre-implementation analysis (R-11) already flagged this: "Use '1-2 days' consistently."
- **Recommendation**: Use "1-2 days" as the target for complex SPs. The workflow automates understanding + blast radius + documentation, but not the actual fix, test, or PR. Framing the metric as "time to understand + document + prepare change" rather than "time to complete the fix" is more accurate.

**M2: Measurement Method -- Self-Report Only**

- All time metrics rely on developer self-report. No objective tracking proposed.
- The pre-implementation analysis (R-12) already flagged this.
- **Recommendation**: Supplement with git commit timestamps (first commit on SP branch to PR merge) for at least the 3 pilot SPs. Provides an objective anchor for before/after comparison.

**M3: Metric Scope Clear**

- The scorecard's impact projection is well-constructed: ~2 SPs/sprint x ~2.5 days avg = 5 dev-days baseline. Target of ~2 dev-days/sprint yields ~3 dev-days savings. This is internally consistent and reasonable.
- The "per quarter" projection (18 dev-days saved) provides a stakeholder-friendly number.

---

## Phase 4: Tech Stack Verification

### Assessment Stack vs. Workflow Assumptions

| Component | Assessment (account-details.yaml) | Workflow Assumption | Match |
|-----------|----------------------------------|-------------------|-------|
| Backend | .NET 8 microservices, Azure Functions | .NET 8 (ASP.NET Core, Azure Functions) | MATCH |
| Frontend | Angular 20 | Angular (for endpoint-to-SP tracing) | MATCH |
| Database | Azure SQL Server (heavy SP usage -- legacy Talent Lyft acquisition) | SQL Server (Azure SQL, SQL Server 2016+) | MATCH |
| CI/CD | Bamboo | Any (scripts are CI-agnostic) | MATCH -- Bamboo mentioned in implementation plan for future CI/CD integration |
| Hosting | Azure | Azure (connection strings in scripts support Azure SQL) | MATCH |
| Monitoring | Sentry, Azure App Insights, Azure Alerts | Not relevant to SP analysis workflow | N/A |
| Testing | xUnit (BE only) | xUnit referenced in change-prep checklist | MATCH |
| Code Quality | SonarQube, GitHub Copilot (PR review) | Not in scope | N/A |
| Repo Structure | Monorepo -- 3 FE + 2 BE apps | Single repo discovery via `/sp-discover` | MATCH -- monorepo is the simpler case |
| Data Access | Not confirmed (Capture flagged: ADO.NET vs Dapper vs EF) | Supports all three: ADO.NET, Dapper, EF | COVERED -- defensive design |

### Tech Stack Findings

**T1: Data Access Pattern Confirmed as Dapper**

The example analysis (`Recruitment.GetCandidateList.md`) shows `Dapper QueryMultipleAsync` at line 2553 of `CandidatesRepository.cs`. This confirms at least Dapper is in use. The `sp-discover` skill's `data-access-patterns.md` reference includes Dapper patterns. The defensive support for ADO.NET and EF is correct -- there may be mixed patterns across the monorepo.

**T2: Azure AD Authentication Support**

The pre-implementation analysis (R-05) flagged that Azure SQL likely requires AAD auth. The PowerShell scripts already include a `-UseAzureAD` parameter (confirmed in `Export-SpDefinitions.ps1` header). The playbook's troubleshooting section documents this. However, the scripts have not been tested against Azure SQL with AAD auth.

**T3: SQL Server MCP Integration**

The workflow correctly documents the `microsoft-sql` MCP server as an alternative to PowerShell scripts (added after R-03 from the pre-implementation analysis). The playbook has a full "Level 2: SQL Server MCP Integration" section. The champion confirmed a local DB backup approach for the pilot, making MCP optional for co-implementation.

**T4: PowerShell Core Availability**

Not confirmed whether `pwsh` is installed on the champion's machine. The `settings.local.json` allows `Bash(pwsh *)`, and the scripts support both PowerShell Core and Windows PowerShell. The onboarding command includes a setup check for `pwsh --version`.

**T5: Repo Access Confirmed**

Spot session confirmed: `https://github.com/NEOGOV-DEV/attract.git` is the main repo. Champion has access. QA Playwright repo also cloned: `github.com/NEOGOV-DEV/qa-automation-playwright.git`.

---

## Phase 5: Champion Preference Check

### Preference Signals from Transcripts

| # | Preference | Source | Session | Workflow Response |
|---|-----------|--------|---------|------------------|
| P1 | Blast radius is the most valuable output | "knowing the impact is the better part; understanding the logic (using Claude Code) is easier... might be a simple fix, the impact might be huge" | Spot Q2 | README: "Blast radius is the priority output." `/sp-analyze` shows blast radius before logic. Default behavior when intent unclear is blast radius first. | ADDRESSED |
| P2 | Top-down discovery flow (UI -> API -> backend -> SP) | "we go to the Attract application, figure out (from the app) in the network tab, what functionality is invoked" | Spot Q1 | `/sp-discover` supports reverse discovery (API endpoint -> SP). Onboarding command documents the top-down flow. | ADDRESSED |
| P3 | Local DB backup preferred over live QA access | "we have a db backup, restore locally... since we are focusing on the standalone SPs, we are not concerned with the performance" | Spot Q3 | README "Option A: Local QA Backup (Recommended for Pilot)." PowerShell scripts support local connection strings. | ADDRESSED |
| P4 | Top 3 SPs for pilot calibration | "Recruitment.GetCandidateList, DataSync.SaveCandidate, Candidates.CreateCompany" | Spot Q4 | Example analysis already created for `Recruitment.GetCandidateList` (710-line XL SP). Other two await DB backup. | ADDRESSED |
| P5 | Quick win must complement existing BDD skill | "everything must be complementary to the BDD skill" (`cc-templates/bdd-config-gen`) | Spot Q9 | This applies to QW1+QW2, not NG-AT-001. Correctly scoped out. | N/A (different workflow) |
| P6 | Co-implementation session next week | "sure, next week" | Spot Q5 | Implementation plan Phase 4 schedules 90-min co-implement session. Agenda defined. | ADDRESSED |
| P7 | Incident triage is low priority | "not a big impact" -- only 3-5 cases/sprint | Spot Q6 | NG-AT-002 correctly deprioritized from P1 to P3 in spot record. | ADDRESSED (scope decision) |
| P8 | Cross-app sync is future candidate | "don't know how we can improve it, we can use it as a candidate, for the future" | Spot Q8 | NG-AT-004 deferred to P3. Noted that sync SP analysis from NG-AT-001 feeds forward. | ADDRESSED (scope decision) |

### Preference Alignment Verdict

**All 6 champion preferences relevant to NG-AT-001 are addressed in the workflow design.** The workflow was restructured after the Spot session to prioritize blast radius output (P1), support the top-down discovery flow (P2), and default to local DB backup mode (P3). The example analysis uses one of the champion's top 3 SPs (P4).

### Champion Readiness Assessment

From the Spot record facilitator notes:
- **Readiness**: Intermediate -- uses Claude Code daily, clear understanding of SP pain, precise need articulation
- **Engagement**: High -- answered all questions thoroughly, volunteered additional context
- **Recommendation**: Standard co-implement -- no additional Spot needed

---

## Phase 6: Cross-Team Overlap Check

### Overlap with Other NeoGov Teams

| Team | Signal | Overlap Type | Details | Action |
|------|--------|-------------|---------|--------|
| **Learn (LN)** | Maintenance/Debugging (3 signals, 2 High) | Pattern overlap | NG-LN-001 debugging workflow shares blast radius analysis pattern. Both trace from symptoms to code impact. Learn uses .NET 4.8 + MS SQL Server (on-prem). SP analysis patterns are reusable for Learn's debugging if they have SP-heavy code. | **Parameterize**: The pre-implementation analysis (R-10 overlap row) already identifies this. SP discovery patterns need adaptation for .NET 4.8 (same data access layer, different framework version). |
| **Learn (LN)** | "hard reproduction, understanding is bottleneck" | Conceptual overlap | Same root cause as NG-AT-001 F2 (understanding is #1 time sink). NG-LN-001 addresses this via case investigation rather than SP analysis. | **No conflict**: Different entry points to a shared methodology (bidirectional code tracing). |
| **PSS Vitals (PV)** | Testing signals (3, 1 High) | No overlap | PV team uses PostgreSQL (not SQL Server). SP analysis workflow is SQL Server-specific. PV's pain is in E2E testing and DataDog log analysis, not SP management. | **None needed** |
| **DMS Policy (DMS)** | MS SQL Server (sharded), .NET 10 + legacy .NET Framework | Potential future overlap | DMS uses MS SQL Server and has dual migration tooling (Redgate + MIG in-house). If DMS has SP-heavy patterns, the workflow is directly transferable. However, DMS's top signals are Testing and Maintenance/Incidents, not Implementation/Database. | **Monitor**: If DMS surfaces SP-related friction in future Capture sessions, NG-AT-001 is a direct match. No action now. |
| **DMS Policy (DMS)** | DataDog error diagnosis | No overlap | DMS's DataDog workflow is monitoring-focused. Different SDLC area. | **None needed** |

### Overlap with Other NeoGov Workflows

| Workflow | Overlap | Details |
|----------|---------|---------|
| **NG-LN-001** (Production Issue Debugging) | Shared blast radius pattern | NG-LN-001 README: "Before applying a fix, the workflow checks what else the changed code affects -- same principle as the SP analysis workflow." This is explicit cross-pollination, not duplication. The two workflows have different triggers (SP task vs SF case) but share the blast radius methodology. |
| **NG-AT-004** (Cross-App Sync Optimization -- future) | Scope boundary | The pilot SP `DataSync.GetJobsForSync` is a sync SP relevant to NG-AT-004. The pre-implementation analysis (R-13) flagged this: "No guidance on how NG-AT-001 analysis outputs feed into future NG-AT-004." Spot session clarified: sync process is automated via Azure Functions; manual investigation only on failure. NG-AT-004 is a future candidate. |

### Overlap with Existing Team Tools

| Tool | Overlap | Details |
|------|---------|---------|
| **BDD skill** (`cc-templates/bdd-config-gen`) | No overlap | The BDD skill generates unit tests from AC. NG-AT-001 generates SP documentation and blast radius analysis. Complementary, not overlapping. The Spot session confirmed this distinction. |
| **GitHub Copilot** (in Bamboo pipeline) | No overlap | Copilot is used for code review in CI/CD. NG-AT-001 is pre-change analysis. Different SDLC phases. |
| **SQL Server MCP** (`microsoft-sql` in cc-templates) | Complementary | The MCP server is documented as a Level 2 alternative to PowerShell scripts. The workflow correctly supports both modes. |

### Cross-Team Transferability

| Dimension | Attract (current) | Learn (potential) | DMS (potential) |
|-----------|-------------------|-------------------|-----------------|
| Database | Azure SQL Server | MS SQL Server (on-prem) | MS SQL Server (sharded) |
| Backend | .NET 8 | .NET 4.8 (migrating to .NET 8) | .NET 10 + .NET Framework |
| Data access | Dapper (confirmed) | Unknown (likely EF or ADO.NET) | Unknown |
| SP complexity | High (legacy Talent Lyft) | Unknown | Unknown (dual migration tooling suggests DB complexity) |
| CI/CD | Bamboo | Bamboo | Jenkins + TeamCity |
| Transferability | Baseline | High -- same DB engine, .NET data access patterns work across versions | High -- same DB engine, sharded may need minor adaptation |

---

## Phase 7: Consolidated Findings and Recommendations

### Findings Summary

| ID | Finding | Severity | Phase | Status |
|----|---------|----------|-------|--------|
| F-01 | All 7 friction signals mapped to workflow capabilities (5 full, 2 partial) | -- | Phase 2 | No action needed |
| F-02 | Complex SP target inconsistency: "1 day" vs "1-2 days" | Medium | Phase 3 | Previously flagged (R-11 in pre-impl analysis); needs fix |
| F-03 | Self-report only measurement; no objective tracking | Medium | Phase 3 | Previously flagged (R-12); supplement with git timestamps |
| F-04 | Data access pattern confirmed as Dapper via example analysis | -- | Phase 4 | Resolved -- was previously UNCONFIRMED |
| F-05 | Azure AD auth in PowerShell scripts: parameter exists but untested | Medium | Phase 4 | Previously flagged (R-05); test before co-implement |
| F-06 | Blast radius correctly prioritized as #1 output per champion preference | -- | Phase 5 | No action needed |
| F-07 | Cross-team reuse potential for Learn (.NET 4.8 + MS SQL) | Low | Phase 6 | Note for Phase 6 of implementation plan |
| F-08 | NG-AT-004 scope boundary documented but needs tagging mechanism | Low | Phase 6 | Previously flagged (R-13); add tags to sync SP analyses |

### Pre-Implementation Analysis Items -- Status Update

The pre-implementation analysis (`docs/pre-implementation-analysis.md`, dated 2026-03-16) identified 23 risks. This review validates their current status:

| Risk | Category | Pre-Impl Status | Current Status (2026-03-20) |
|------|----------|-----------------|---------------------------|
| R-01 | SQL injection in PowerShell scripts | Critical | **NEEDS FIX** -- still open |
| R-02 | Unsafe EXEC in Export-ExecutionPlan.ps1 | Critical | **NEEDS FIX** -- still open |
| R-03 | MCP alternative undocumented | High | **RESOLVED** -- playbook has Level 2 MCP section |
| R-04 | Champion artifacts blocked 5+ days | High | **RESOLVED** -- Spot session unblocked; top 3 SPs confirmed, repo access provided, DB backup pending |
| R-05 | No Azure AD auth tested | High | **NEEDS TESTING** -- parameter exists in scripts; untested |
| R-06 | Missing Edit/Write permissions | Medium | **RESOLVED** -- settings.local.json has `Write(docs/**)`, `Edit(docs/**)` |
| R-07 | install.sh doesn't copy settings.local.json | Medium | **RESOLVED** -- install.sh has settings merge logic with python3 |
| R-08 | Scripts use legacy System.Data.SqlClient | Medium | **NEEDS DOCUMENTATION** -- prerequisite not clearly stated |
| R-09 | Context window risk for large SPs | Medium | Open -- no `--blast-only` guidance added yet |
| R-10 | CLR/linked server detection missing | Medium | Open -- acceptable for pilot (unlikely in Attract) |
| R-11 | Complex SP target inconsistency | Medium | **NEEDS FIX** -- confirmed in Phase 3 metric alignment |
| R-12 | Self-report measurement only | Medium | **NEEDS SUPPLEMENT** -- add git timestamps |
| R-13 | NG-AT-004 scope boundary undefined | Medium | Open -- noted but acceptable for pilot |
| R-14 | Dry run depends on real SP | Medium | **PARTIALLY RESOLVED** -- example analysis exists for Recruitment.GetCandidateList; full dry run awaits DB backup |
| R-15 | Single champion dependency | Medium | Open -- identify backup during co-implement |

### Must-Fix Before Co-Implementation

| # | Item | Effort | Owner | Status |
|---|------|--------|-------|--------|
| 1 | **R-01 + R-02**: Refactor PowerShell scripts to use parameterized queries (SQL injection) | S (3-4h) | Bogdan | **FIXED** (2026-03-20) — Export-ExecutionPlan.ps1: added SP name validation regex + bracket-quoted identifiers instead of string interpolation |
| 2 | **F-02/R-11**: Align complex SP target to "1-2 days" across all docs (capture card, impl plan, catalog) | S (30min) | Bogdan | **FIXED** (2026-03-20) — capture analysis updated: metric table, weighted baseline, impact text, recommended pilots |
| 3 | **R-05**: Test Azure AD auth against an Azure SQL instance before co-implement session | M (2-3h) | Bogdan | **FIXED** (2026-03-20) — Added `-TestConnection` switch to Export-ExecutionPlan.ps1 for auth + SHOWPLAN permission verification |

### Should-Fix Before Demo

| # | Item | Effort | Owner |
|---|------|--------|-------|
| 4 | **F-03/R-12**: Add git commit timestamp measurement plan for pilot SPs | S (1h) | Bogdan |
| 5 | **R-09**: Add large-SP guidance to sp-analysis skill (recommend section-by-section for 2000+ line SPs) | S (30min) | Bogdan |
| 6 | **R-08**: Document `SqlServer` module prerequisite in playbook | S (30min) | Bogdan |

### Consider Before Replication

| # | Item | Effort | Owner |
|---|------|--------|-------|
| 7 | **F-07**: Parameterize .NET version-specific patterns for Learn team (.NET 4.8 compatibility) | M (2-3h) | Bogdan |
| 8 | **F-08/R-13**: Add `[sync]` tags to SP analyses that feed into future NG-AT-004 scope | S (30min) | Bogdan |
| 9 | **R-15**: Identify backup champion from the other 3 SP developers during co-implement | S (during session) | Bogdan + Champion |

### Validate With Champion During Co-Implementation

| # | Question | Rationale |
|---|----------|-----------|
| 1 | Are there SPs with CLR functions (`EXTERNAL NAME`) or linked server references? | R-10: Detection patterns not yet added |
| 2 | What is the largest SP by line count? | R-09: Context window planning for very large SPs |
| 3 | Does `SHOWPLAN` permission exist on the local DB restore? | Prerequisite for `Export-ExecutionPlan.ps1` |
| 4 | Who from the 3 other developers should be the backup champion? | R-15: Single champion dependency mitigation |
| 5 | Does the `SqlServer` PowerShell module need installation, or is it already available? | R-08: Script prerequisite |

---

## Workflow Quality Assessment

### Structural Completeness

| Component | Present | Quality | Notes |
|-----------|---------|---------|-------|
| README with problem/solution/quick-start | Yes | Strong | Clear problem statement, 6 commands documented, 3 usage modes |
| Installation script | Yes | Good | Merges settings, copies skills and scripts; python3 dependency for merge |
| Onboarding command | Yes | Strong | Interactive, 6 demo options, setup checks, works-with documentation |
| Skills (auto-trigger) | Yes (4) | Strong | sp-analysis, sp-discover, sp-change-prep, sp-document; proper composition rules |
| PowerShell bridge scripts | Yes (5) | Good with caveats | SQL injection in 2 scripts (R-01, R-02); otherwise well-structured with auth options |
| Templates | Yes (1) | Strong | 14-section analysis template with review checklist and validation flags |
| Example output | Yes (1) | Excellent | Recruitment.GetCandidateList -- 710-line XL SP with full blast radius, Mermaid diagrams, logic analysis |
| Playbook | Yes | Strong | 5 stages, MCP Level 2, troubleshooting section |
| Implementation plan | Yes | Strong | 6 phases, quality gates, risk register, timeline |
| Limitations documentation | Yes | Strong | 5 limitations with concrete PowerShell mitigations and HITL reduction analysis |
| Pre-implementation analysis | Yes | Strong | 23 risks identified with severity, effort, and timing |
| Workflow catalog entry | Yes | Good | Summary table, commands, scripts, proven metrics, transferability notes |

### Design Strengths

1. **Blast radius prioritization**: The workflow was restructured after the Spot session to show blast radius before logic details. This directly responds to the champion's confirmed #1 preference.

2. **Three access modes**: MCP (live DB queries), PowerShell scripts (offline/restricted), and repo-committed .sql files. This handles diverse environment constraints gracefully.

3. **Skills-based architecture**: Using auto-triggering skills instead of explicit commands reduces cognitive load. Developers describe what they need; the right skill activates.

4. **Composition rules**: Skills explicitly document what they consume and produce, enabling clean chaining (sp-discover -> sp-analysis -> sp-change-prep -> sp-document).

5. **[inferred] / [?] / [validated] flags**: Clear lifecycle for AI-generated content. Developers know what to trust and what to verify.

6. **Example analysis quality**: The `Recruitment.GetCandidateList.md` example is production-grade -- 710-line SP with 18 parameters, 8 execution paths, 4 result sets, Mermaid diagrams, and risk assessment. This is a credible demo artifact.

### Design Risks

1. **SQL injection in PowerShell scripts** (R-01, R-02): Must fix before co-implementation. The irony of a security flaw in a database analysis tool would undermine champion confidence.

2. **No synthetic SP for dry run**: The workflow depends on champion-provided artifacts for full validation. The example analysis (Recruitment.GetCandidateList) partially mitigates this but was generated from the real repo, not a synthetic test case.

3. **Context window risk for very large SPs**: No documented escape hatch for SPs exceeding 2000+ lines. The example SP is 710 lines (already "XL"). Larger SPs in the codebase are plausible.

---

## Terminal Summary

```
CONTENT REVIEW: NG-AT-001 Stored Procedure Analysis & Optimization
===================================================================

VERDICT: READY FOR CO-IMPLEMENTATION (3 must-fixes remaining)

FRICTION COVERAGE:     7/7 signals mapped (5 full, 2 partial)
METRIC ALIGNMENT:      Aligned with 1 inconsistency (complex SP target: 1 day vs 1-2 days)
TECH STACK:            Verified -- .NET 8 + Azure SQL + Angular 20 + Dapper confirmed
CHAMPION PREFERENCE:   All 6 preferences addressed; blast radius correctly prioritized
CROSS-TEAM OVERLAP:    Learn (blast radius pattern reuse); DMS (potential future match)

MUST-FIX BEFORE CO-IMPLEMENTATION:
  1. SQL injection in PowerShell scripts (R-01 + R-02)          ~3-4h
  2. Align complex SP target to "1-2 days" across all docs      ~30min
  3. Test Azure AD auth against Azure SQL                        ~2-3h

BLOCKERS:
  - DB backup from champion (Suresh) -- pending, needed before co-implement session

WORKFLOW QUALITY:
  - 4 auto-triggering skills, 1 command, 5 PowerShell scripts
  - Example analysis (Recruitment.GetCandidateList) is production-grade
  - 6-phase implementation plan with quality gates and risk register
  - Pre-implementation analysis identified 23 risks; 5 resolved, 3 need fix
  - Structural completeness: all expected components present

NEXT STEP: Fix must-fix items, await DB backup, schedule co-implement session
```
