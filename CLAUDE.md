# NG-AT-001: Stored Procedure Analysis & Optimization Workflow

## What This Is

AI-powered workflow for understanding, documenting, and safely modifying legacy stored procedures in .NET 8 + Azure SQL codebases. Installed into a target repo via `scripts/install.sh`.

## Target Stack

- **Backend**: .NET 8 (ASP.NET Core, Azure Functions)
- **Database**: Azure SQL Server (heavy SP usage — legacy Talent Lyft acquisition)
- **Data access**: Dapper (primary), ADO.NET, Entity Framework
- **Frontend**: Angular 20 (for endpoint-to-SP tracing)
- **CI/CD**: Bamboo

## Skills (Auto-Trigger)

| Skill | Triggers When |
|-------|--------------|
| `sp-quick-fix` | Developer says "fix SP X, issue Y — work with me" — guided step-by-step fixing |
| `sp-test-data` | Developer wants sample data for testing, or is a new colleague onboarding |
| `sp-analysis` | Developer asks about an SP, pastes SP name, or asks "what does X do?" |
| `sp-discover` | Developer explores SP references or asks "what SPs does this codebase use?" |
| `sp-change-prep` | Developer plans to modify an SP or asks about impact of a change |
| `sp-document` | Developer asks to document an SP or generate SP documentation |

## Commands

| Command | Purpose |
|---------|---------|
| `/onboarding` | Interactive walkthrough — start here |

## Key Principles

1. **Blast radius first** — always show who calls an SP before showing its logic
2. **Validation flags** — AI inferences marked `[inferred]`, developer confirms
3. **Three access modes**: SQL Server MCP (live) / PowerShell scripts (offline) / repo-committed .sql files
4. **Never auto-commit** — use `/git:commit` and `/pr:create` from global commands

## Database Access

- **PowerShell scripts** in `scripts/powershell/` bridge the gap when MCP is unavailable
- **SQL Server MCP** (`microsoft-sql`) replaces PowerShell scripts when enabled
- **Local QA backup** is the recommended pilot approach — no live DB access needed

## Output Locations

- `docs/sp-analysis/` — generated SP analysis documents
- `docs/sp-definitions/` — exported SP source code (.sql files)
- `docs/sp-metadata/` — exported parameters, dependencies, indexes
- `templates/sp-analysis-template.md` — template for SP documentation
