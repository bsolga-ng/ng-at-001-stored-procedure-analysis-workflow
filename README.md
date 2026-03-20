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
2. **Trace from the UI**: Open the app → Developer Tools → Network tab → identify the API call → search for that endpoint in the .NET backend
3. **Run `/sp-analyze {sp-name}`** — blast radius is shown first, then full analysis
4. **Review** the blast radius (who calls this SP), then logic details
5. **Run `/sp-change-prep {sp-name}`** before making any modifications

> **Blast radius is the priority output.** Even a simple fix can have huge downstream impact. The workflow shows blast radius before logic details so you know the impact before you change anything.

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

## Database Access

### Option A: Local QA Backup (Recommended for Pilot)

Restore a database backup from QA locally. This is the standard approach for the pilot — no need to connect to live QA environments.

```bash
# Restore QA backup to local SQL Server
sqlcmd -S localhost -Q "RESTORE DATABASE AttractDB FROM DISK = '/path/to/attract-qa-backup.bak'"
```

Then connect via MCP or PowerShell scripts using the local connection string.

### Option B: SQL Server MCP (Recommended for Live Analysis)

If the `microsoft-sql` MCP server is enabled, Claude Code queries the database directly — no PowerShell scripts needed for exploration.

```bash
# Enable the MCP server (if using cc-templates)
# Edit ~/.claude.json → set microsoft-sql "disabled": false

# Or add directly
claude mcp add --transport stdio microsoft-sql -- \
  npx -y @anthropic/mcp-server-sql-server \
  --connection-string "Server=localhost;Database=AttractDB;Trusted_Connection=True"
```

With MCP, `/sp-discover` and `/sp-analyze` fetch SP definitions, metadata, and stats live from the database.

### Option B: PowerShell Scripts (Database Bridge)

For environments where MCP is unavailable, PowerShell scripts export data to files that Claude Code analyzes.

| Script | Purpose | Replaced by MCP? |
|--------|---------|-------------------|
| `Export-SpDefinitions.ps1` | Export SP definitions to .sql files | Yes |
| `Export-SpMetadata.ps1` | Export parameters, dependencies, indexes | Yes |
| `Export-ExecutionPlan.ps1` | Capture execution plan XML + summary | Yes |
| `Get-SpStats.ps1` | Export runtime stats from DMVs | Yes |
| `Test-SpChange.ps1` | Before/after regression diff | **No — always needed** |

All scripts support:
- **Windows Integrated auth** (default)
- **SQL auth** (`-Credential`)
- **Azure AD auth** (`-UseAzureAD`, requires `SqlServer` module)
- **Microsoft.Data.SqlClient** (preferred) with **System.Data.SqlClient** fallback

**Three usage modes:**

| Mode | How | When |
|------|-----|------|
| **MCP** | Claude Code queries DB directly via MCP server | MCP available, real-time analysis |
| **Integrated** | Claude Code invokes scripts via `pwsh` | MCP unavailable, PowerShell Core installed |
| **Manual** | Developer runs scripts, feeds output files to Claude Code | Offline or restricted environments |

See [Playbook](docs/playbook.md) for detailed setup of each mode.

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
