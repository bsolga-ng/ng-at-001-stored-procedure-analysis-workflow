---
command: sp-blast-radius
description: Quick blast radius check — find all .NET code paths that invoke a stored procedure
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-11 20:00 UTC+0200
---

# SP Blast Radius

Quick-focused command: find all code paths that invoke a given stored procedure and assess the risk of changing it.

## Arguments
- `$ARGUMENTS` - SP name (e.g., `DataSync.GetJobsForSync`)

## Instructions

Find every place in the .NET codebase that calls this SP and trace each call chain to its entry point.

### Step 1: Find Direct References

Search the entire codebase for `$ARGUMENTS` as a string:
- String literals: `"$ARGUMENTS"`
- Constants containing the name
- SQL files referencing the SP
- Config files or enums

### Step 2: Trace Call Chains

For each direct reference:
1. **Repository layer**: Method and class containing the SP call
2. **Service layer**: What calls the repository method
3. **Controller layer**: What calls the service method
4. **Entry point**: HTTP endpoint, Azure Function trigger, background job, or message handler

### Step 3: Cross-SP Dependencies

Check if this SP:
- Is called by other SPs (`EXEC $ARGUMENTS` in other .sql files)
- Calls other SPs (from Phase 2 of `/sp-analyze` if already run)
- Shares tables with other SPs that might be affected by schema changes

### Output

```markdown
# Blast Radius: {SP Name}

**Risk Level**: {Low / Medium / High}
**Direct .NET references**: {N}
**Affected endpoints**: {N}
**Cross-SP dependencies**: {N}

## Invocation Map

{Mermaid sequence diagram showing all call chains}

## .NET Call Chains

### Chain 1: {Endpoint} → {SP}
| Layer | Class | Method | File |
|-------|-------|--------|------|
| Entry Point | {Controller} | {Action} | {file:line} |
| Service | {Service} | {Method} | {file:line} |
| Repository | {Repo} | {Method} | {file:line} |
| SP Call | — | {SP Name} | {file:line} |

### Chain 2: ...

## Cross-SP Dependencies

| Related SP | Relationship | Shared Tables |
|-----------|-------------|---------------|
| {sp_name} | Calls this SP | — |
| {sp_name} | Shares table {X} | {table} |

## Risk Assessment

- **Change to parameters**: Affects {N} callers — {list}
- **Change to result set**: Affects {N} consumers — {list}
- **Change to tables**: Shared with {N} other SPs — {list}
```

### Quality Gate

| Criterion | Pass |
|-----------|------|
| All string references found | [ ] |
| Call chains traced to entry points | [ ] |
| Risk level assigned | [ ] |
| Invocation map diagram renders | [ ] |
