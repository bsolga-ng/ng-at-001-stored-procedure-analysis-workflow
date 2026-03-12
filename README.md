# Stored Procedure Analysis & Optimization Workflow

A methodology and tooling for understanding, documenting, and safely modifying legacy stored procedures in SQL Server databases using GenAI (Claude Code).

## The Problem

Legacy codebases accumulate undocumented stored procedures — inherited through acquisitions, grown over years of feature additions, with no documentation, no knowledge base, and no way to assess the blast radius of a change. Developers spend days understanding a single SP before they can safely modify it:

- **No documentation** for 100+ stored procedures — every investigation starts from scratch
- **No blast radius visibility** — SPs are invoked from multiple .NET code paths with no dependency map
- **Regression risk** — changes to one SP can break unknown consumers
- **4-5 days** for complex SP fixes (sync processes), 3 days for moderate, 1 day for simple

## The Solution

**SP-Anchored Analysis** — Generate comprehensive understanding of stored procedures by tracing them bidirectionally: downward into SQL logic (parameters, tables, JOINs, dynamic SQL) and upward into .NET code (which controllers, services, and repositories invoke them).

| Phase | Role | Cardinality |
|-------|------|-------------|
| **1. Discovery** | Find all SPs in the codebase, build registry | 1x per repo |
| **2. Analysis** | Deep-dive into one SP: logic, parameters, dependencies | Nx per SP task |
| **3. Blast Radius** | Map all .NET invocation points for a given SP | Nx per SP task |
| **4. Documentation** | Generate structured SP documentation | Nx per SP |
| **5. Change Assist** | Pre-change impact analysis + post-change validation scripts | Nx per SP modification |

## Quick Start

1. **Install the tooling** in your target repository (see [Installation](#installation))
2. **Run `/sp-discover`** to build your SP registry
3. **Pick the SP** you need to work on
4. **Run `/sp-analyze {sp-name}`** for full analysis
5. **Review** generated documentation, assess blast radius, proceed with change

---

## Installation

### From Source Repository (push)

```bash
./scripts/install.sh /path/to/your-dotnet-project
```

### From Target Project (pull)

Start Claude Code in your project and ask:

> Import the SP analysis workflow from the neogov-workflows repository

---

## Claude Code Commands

| Command | Purpose |
|---------|---------|
| `/onboarding` | Interactive walkthrough of the workflow |
| `/sp-discover [path]` | Find all SP references in .NET code, build registry |
| `/sp-analyze {sp-name}` | **Full analysis**: logic, parameters, dependencies, blast radius, docs |
| `/sp-blast-radius {sp-name}` | Quick blast radius check — all .NET invocation points |
| `/sp-document {sp-name}` | Generate/update structured documentation for one SP |
| `/sp-change-prep {sp-name}` | Pre-change analysis: impact assessment + validation script |

**Usage examples:**
```bash
/onboarding                               # Interactive walkthrough
/sp-discover src                          # Build SP registry from .NET code
/sp-analyze DataSync.GetJobsForSync       # Full analysis of one SP
/sp-blast-radius DataSync.GetJobsForSync  # Quick: who calls this SP?
/sp-document DataSync.GetJobsForSync      # Generate docs only
/sp-change-prep DataSync.GetJobsForSync   # Pre-change impact + test script
/sp-analyze DataSync.GetJobsForSync --quick  # Skip interactive, use defaults
```

---

## PowerShell Scripts (Database Bridge)

Claude Code cannot connect to databases. These PowerShell scripts bridge the gap by extracting deterministic data from SQL Server that Claude Code can then analyze.

| Script | Purpose | Requires DB Access |
|--------|---------|-------------------|
| `Export-SpDefinitions.ps1` | Export all SP definitions to .sql files | Yes |
| `Export-SpMetadata.ps1` | Export SP parameters, dependencies, table references | Yes |
| `Export-ExecutionPlan.ps1` | Capture execution plan for a given SP + parameters | Yes |
| `Test-SpChange.ps1` | Run SP before/after with same params, diff results | Yes |
| `Get-SpStats.ps1` | Export runtime stats (execution count, avg duration) | Yes |

**Two usage modes:**

| Mode | How | When |
|------|-----|------|
| **Manual** | Developer runs PowerShell scripts, feeds output files to Claude Code | No shell access to DB from Claude Code |
| **Integrated** | Claude Code invokes scripts via `pwsh` (if PowerShell Core installed) | Full automation |

See [PowerShell Scripts Guide](docs/powershell-scripts.md) for details.

---

## Supported Stack

- **Database**: SQL Server (Azure SQL, SQL Server 2016+)
- **Backend**: .NET 8 (ASP.NET Core, Azure Functions)
- **ORM/Data Access**: ADO.NET, Dapper, Entity Framework (SP calls)
- **Frontend**: Angular (for endpoint-to-SP tracing)
- **CI/CD**: Any (scripts are CI-agnostic)

## Key Principles

1. **Understand before modify** — Generate analysis for the SP you're about to change
2. **Blast radius first** — Always know who calls this SP before changing it
3. **Deterministic bridge** — Use PowerShell scripts for data Claude Code can't access
4. **Validation flags** — AI inferences marked `[inferred]`, developer confirms
5. **Minimize HITL** — Automate everything automatable; human reviews only what needs judgment

## License

Internal use.
