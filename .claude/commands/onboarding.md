---
command: onboarding
description: Interactive walkthrough of the SP analysis workflow
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-16 14:00 UTC+0200
---

# Onboarding — SP Analysis Workflow

Welcome to the Stored Procedure Analysis workflow. This guide walks you through the available skills and how they fit into your development process.

## Instructions

Present this information interactively, adapting to the developer's experience level.

### Introduction

"This workflow helps you understand, document, and safely modify stored procedures. It traces SPs from the UI all the way down to the database and back up through your .NET code to assess the **blast radius** of any change.

**Your typical starting point:**

```
1. Open the Attract app in the browser
2. Open Developer Tools → Network tab
3. Reproduce the issue or navigate to the feature
4. Identify the REST API call (e.g., GET /api/attract/candidates)
5. Search for that endpoint in the .NET backend code
6. Find which stored procedure the endpoint calls
7. → Now you have the SP name — run the analysis
```

This top-down flow (UI → API → Backend → SP) is how most SP work starts. The workflow supports this by tracing both directions: from .NET code down to SPs, and from SPs up to all their callers.

**What it focuses on (in priority order):**
1. **Blast radius** — who calls this SP, what breaks if you change it ← *highest value*
2. **SP logic** — parameters, tables, JOINs, dynamic SQL
3. **Documentation** — structured docs with Mermaid diagrams
4. **Change prep** — impact analysis and validation scripts before you modify

**How it works — skills auto-trigger based on your task:**

| What You Say | What Activates |
|-------------|----------------|
| "I'm looking at this API endpoint, what SP does it call?" | SP Discovery — traces endpoint to SP |
| "What SPs does this codebase use?" | SP Discovery — builds a registry of all SP references |
| "What's the blast radius of Recruitment.GetCandidateList?" | SP Analysis — blast radius first, then full analysis |
| "What does this SP do?" | SP Analysis — full analysis with blast radius and docs |
| "I need to change this SP" | SP Change Prep — impact analysis + validation scripts |
| "Document this SP" | SP Documentation — generate docs or coverage report |

You don't need to remember command names. Just describe what you need and the right skill activates.

**Database access — three options:**

| Method | Setup | Best For |
|--------|-------|----------|
| **SQL Server MCP** (recommended) | Enable `microsoft-sql` MCP server — Claude Code queries the DB directly | Real-time analysis, no manual exports |
| **PowerShell scripts** | Run `Export-SpDefinitions.ps1` etc. to export data to files | MCP unavailable, offline analysis |
| **SP files in repo** | If `.sql` files are already checked into the codebase | No DB access needed |

**What it can't do (and the workarounds):**
- Can't execute SPs to test them — use `Test-SpChange.ps1` to capture before/after snapshots
- Static analysis only — dynamic SQL paths are flagged but may need manual verification
- Items marked `[inferred]` need developer confirmation; items marked `[?]` need investigation"

### Setup Check

Before proceeding, check the developer's environment:

1. **MCP availability**: Check if `microsoft-sql` MCP server is available. If enabled, no PowerShell exports needed.
2. **SP definitions**: Check if `.sql` files exist in the repo (e.g., `docs/sp-definitions/` or a migrations folder). If not, they need to be exported via PowerShell or fetched live via MCP.
3. **PowerShell Core**: Check if `pwsh` is available (needed for validation scripts regardless of MCP). Run: `pwsh --version`
4. **SqlServer module** (for Azure SQL): If connecting to Azure SQL, check: `pwsh -c "Get-Module -ListAvailable SqlServer"`
5. **Superpowers plugin**: If installed, TDD enforcement and systematic debugging auto-activate alongside SP analysis skills.
6. **Git/PR commands**: Verify `/git:commit` and `/pr:create` are available for the commit-and-review step.

Report findings and recommend the appropriate setup path.

### Workflow Overview

Present the typical developer workflow:

```
0. TRACE             Browser → Network tab → find API call → search in .NET code → identify SP
   → You now have the SP name
        |
1. BLAST RADIUS      "What's the blast radius of {sp-name}?"
   → All .NET callers: Endpoint → Controller → Service → Repository → SP
        |
2. ANALYZE           "What does {sp-name} do?"
   → Logic, parameters, tables, dynamic SQL
        |
3. CHANGE PREP       "I need to modify {sp-name}"
   → Impact analysis + validation scripts
        |
4. (Make the change)  Developer modifies SP
        |
5. VALIDATE          Run Test-SpChange.ps1 -Phase after
   → Compare before/after snapshots
        |
6. UPDATE DOCS       "Update the docs for {sp-name}"
   → Documentation refreshed
        |
7. COMMIT            /git:commit → /pr:create
   → Changes committed and PR created
```

**Step 0 is manual** — you do this in the browser. Everything from Step 1 onward is automated by the workflow.

**With MCP enabled**, steps 1-3 query the database live — no manual PowerShell exports needed.
**Without MCP**, run the PowerShell export scripts first (see Playbook Stage 1).

### Interactive Demo

Offer to demonstrate:

"Would you like me to:
1. **See an example analysis** — [Recruitment.GetCandidateList](../../docs/examples/Recruitment.GetCandidateList.md) (710-line XL SP, blast radius + full logic)
2. **Check your setup** — detect MCP, PowerShell, SP definitions, and recommend next steps
3. **Run discovery** on your codebase to find all SP references
4. **Analyze a specific SP** you're working on right now
5. **Show the PowerShell scripts** for database interaction (if MCP is unavailable)
6. **Just show the skill list** and let you explore on your own"

Proceed based on the developer's choice.

### Skills (auto-trigger)

| Skill | Triggers When | What It Does |
|-------|---------------|-------------|
| SP Discovery | No SP registry exists; developer asks about SPs in codebase | Scans .NET code for ADO.NET/Dapper/EF patterns, builds registry |
| SP Analysis | Developer asks about an SP, mentions modifying or debugging one | Parses logic, traces blast radius, generates Mermaid docs |
| SP Change Prep | Developer intends to modify an SP | Impact analysis, validation scripts, change checklist |
| SP Documentation | Developer asks to document SPs or check coverage | Single/batch docs, coverage audit |

### PowerShell Scripts (when MCP is unavailable)

| Script | Purpose | Auth Options |
|--------|---------|--------------|
| `Export-SpDefinitions.ps1` | Export SP definitions to .sql files | Windows, SQL, Azure AD |
| `Export-SpMetadata.ps1` | Export params, dependencies, indexes | Windows, SQL, Azure AD |
| `Get-SpStats.ps1` | Export runtime stats from DMVs | Windows, SQL, Azure AD |
| `Export-ExecutionPlan.ps1` | Capture execution plan XML + summary | Windows, SQL, Azure AD |
| `Test-SpChange.ps1` | Before/after regression diff (**always needed**) | Windows, SQL, Azure AD |

All scripts support `-UseAzureAD` for Azure SQL, and auto-detect `Microsoft.Data.SqlClient` with `System.Data.SqlClient` fallback.

### Works With

- **Superpowers TDD** — when writing tests for SP consumers, TDD enforcement activates automatically
- **Superpowers Debugging** — when debugging SP issues, systematic debugging provides root-cause discipline
- **Superpowers Verification** — analysis outputs serve as verification evidence
- **`/git:commit`** — commit generated analysis and documentation
- **`/pr:create`** — create PRs with SP change context
