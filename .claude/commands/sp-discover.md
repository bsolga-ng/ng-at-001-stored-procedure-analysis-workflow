---
command: sp-discover
description: Find all stored procedure references in .NET code and build SP registry
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-11 20:00 UTC+0200
---

# Discover Stored Procedures

Scan the .NET codebase to find all stored procedure references and build a comprehensive SP registry.

## Arguments
- `$ARGUMENTS` - Target path to scan (default: `src`)

## Instructions

Scan `$ARGUMENTS` for all references to stored procedures. Build a registry mapping SP names to their .NET invocation points.

### Discovery Patterns

**ADO.NET patterns:**
- `CommandType.StoredProcedure` + `CommandText = "..."`
- `new SqlCommand("sp_name", connection)`
- `EXEC sp_name` in inline SQL strings

**Dapper patterns:**
- `.Query<T>("sp_name", ..., commandType: CommandType.StoredProcedure)`
- `.Execute("sp_name", ..., commandType: CommandType.StoredProcedure)`
- `.QueryFirstOrDefault<T>("sp_name", ...)`

**Entity Framework patterns:**
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

### Pre-Exported Definitions

Check if `Export-SpDefinitions.ps1` output exists:
- `docs/sp-definitions/*.sql` — individual SP definition files
- `docs/sp-metadata/sp-metadata.json` — parameter/dependency metadata

If found, incorporate into the registry for completeness.

### Output Format

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
- etc.

## Missing Definitions

These SPs are referenced in .NET code but have no definition in the repository:

| SP Name | Referenced From | Action Needed |
|---------|----------------|--------------|
| {name} | {file:line} | Run Export-SpDefinitions.ps1 |
```

### Quality Gate

| Criterion | Pass |
|-----------|------|
| All .NET files in scope scanned | [ ] |
| SP names extracted from all access patterns | [ ] |
| Registry saved to `docs/sp-analysis/_index.md` | [ ] |
| Missing definitions flagged | [ ] |

**Exit**: Registry complete, missing definitions identified.
