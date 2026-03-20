---
name: neogov:workflow:sp-discover
description: Discover stored procedure references in .NET codebases and build an SP registry. Use when exploring a .NET repository that calls SQL Server stored procedures, when no SP registry exists (docs/sp-analysis/_index.md), when investigating which SPs a codebase uses, or when onboarding to a legacy codebase with database dependencies. Detects ADO.NET CommandType.StoredProcedure, Dapper .Query/.Execute, Entity Framework FromSqlRaw/ExecuteSqlRaw, constants, enums, and SQL definition files.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *)
---

# Discover Stored Procedures

Scan a .NET codebase to find all stored procedure references and build a comprehensive SP registry.

## When This Skill Triggers

- Developer opens a .NET project with SQL Server stored procedure calls
- No `docs/sp-analysis/_index.md` exists yet
- Developer asks "what stored procedures does this codebase use?"
- Developer asks "what SP does this API endpoint call?" (reverse-trace from endpoint)
- Developer is onboarding to a legacy codebase and needs to understand database dependencies
- Developer mentions stored procedures, SP references, or data access patterns

## Reverse Discovery (API Endpoint → SP)

When a developer starts from the UI (browser Network tab) and has an API endpoint:

1. **Search for the endpoint** in .NET controller files:
   - `[HttpGet("candidates")]`, `[Route("api/attract/...")]`
   - Match the URL path segments to controller route attributes
2. **Trace the controller method** → service method → repository method
3. **Find the SP call** in the repository layer (ADO.NET/Dapper/EF pattern)
4. **Report**: `{endpoint} → {Controller}.{Method} → {Service}.{Method} → {Repository}.{Method} → {SP_NAME}`

This is the most common starting flow — developers identify the API call from the browser Network tab, then need to find which SP backs it.

## Discovery Patterns

Scan across all `.cs` files for these patterns:

**ADO.NET:**
- `CommandType.StoredProcedure` + `CommandText = "..."`
- `new SqlCommand("sp_name", connection)`
- `EXEC sp_name` in inline SQL strings

**Dapper:**
- `.Query<T>("sp_name", ..., commandType: CommandType.StoredProcedure)`
- `.Execute("sp_name", ..., commandType: CommandType.StoredProcedure)`
- `.QueryFirstOrDefault<T>("sp_name", ...)`

**Entity Framework:**
- `.FromSqlRaw("EXEC sp_name ...")`
- `.ExecuteSqlRaw("EXEC sp_name ...")`
- `.FromSqlInterpolated($"EXEC sp_name ...")`

**Constants/Configuration:**
- `const string SpName = "..."`
- Enum values mapping to SP names
- Configuration files referencing SP names

**SQL Definition Files:**
- `CREATE PROCEDURE` / `ALTER PROCEDURE` in `.sql` files
- Migration files containing SP definitions

## Pre-Exported Definitions

Check if PowerShell export output exists:
- `docs/sp-definitions/*.sql` — individual SP definition files
- `docs/sp-definitions/manifest.json` — export manifest
- `docs/sp-metadata/sp-metadata.json` — parameter/dependency metadata

If the `microsoft-sql` MCP server is available, query the database directly instead.

If found, incorporate into the registry for completeness.

## Output

Generate `docs/sp-analysis/_index.md`:

```markdown
# Stored Procedure Registry

> Auto-generated | Last scanned: {DATE} | Status: Draft

## Summary

| Metric | Value |
|--------|-------|
| Total SPs referenced in .NET code | {N} |
| SPs with definitions in repo | {N} |
| SPs with definitions exported | {N} |
| SPs with no definition found | {N} |

## Registry

| # | SP Name | Schema | .NET References | Definition | Complexity | Last Modified |
|---|---------|--------|-----------------|------------|------------|---------------|
| 1 | {name} | {schema} | {N} locations | {In repo / Exported / Missing} | {S/M/L/XL} | {date or —} |

## By Domain

Group SPs by naming convention or functional area:
- **DataSync.*** — Synchronization processes
- **Get*** — Read operations
- **Upsert*** — Write operations

## Missing Definitions

These SPs are referenced in .NET code but have no definition in the repository:

| SP Name | Referenced From | Action Needed |
|---------|----------------|--------------|
| {name} | {file:line} | Run Export-SpDefinitions.ps1 or enable microsoft-sql MCP |
```

## Quality Gate

- [ ] All .NET files in scope scanned
- [ ] SP names extracted from all access patterns (ADO.NET, Dapper, EF, constants)
- [ ] Registry saved to `docs/sp-analysis/_index.md`
- [ ] Missing definitions flagged with action needed

## Composition

- This skill produces the registry that `neogov:workflow:sp-analysis` consumes
- Does NOT generate git commits — developer uses `/git:commit` when ready
- Does NOT replace superpowers skills — works alongside `systematic-debugging` for SP investigation
