---
command: sp-analyze
description: Full analysis of a stored procedure — logic, parameters, blast radius, documentation
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-11 20:00 UTC+0200
---

# Analyze Stored Procedure

Full analysis of a stored procedure: parse logic, extract parameters, map dependencies, trace .NET invocation points, and generate structured documentation.

## Arguments
- `$ARGUMENTS` - SP name (e.g., `DataSync.GetJobsForSync`) or flags

## Instructions

You are analyzing a legacy stored procedure to help a developer understand it before making changes. Your goal is to produce a comprehensive analysis that eliminates the need for manual reverse-engineering.

### Parse Arguments

Determine the mode from `$ARGUMENTS`:
- SP name only → Full analysis mode (interactive)
- `--quick` → Skip interactive questions, use defaults
- `--blast-only` → Blast radius analysis only (equivalent to `/sp-blast-radius`)
- `--doc-only` → Documentation generation only (equivalent to `/sp-document`)

### Phase 0: Context Gathering

**Skip if `--quick` flag is provided.**

Ask the developer:

1. **Task type**: "What are you doing with this SP?"
   - Debugging a bug
   - Optimizing performance
   - Adding/modifying a feature
   - Understanding for knowledge transfer
   - Assessing migration feasibility

2. **Known context**: "What do you already know about this SP?"
   - Nothing — first time looking at it
   - I know what it does roughly, need details
   - I know it well, just need blast radius / impact check

3. **Output needs**: "What would help you most?"
   - Full documentation (all sections)
   - Focus on logic flow + parameters
   - Focus on blast radius + regression risk
   - Focus on optimization opportunities

Use answers to prioritize sections in the output.

### Phase 1: Locate SP Definition

Search for the SP definition in the codebase:

1. **Search patterns** (in priority order):
   - `CREATE PROCEDURE [{schema}.]$SP_NAME` or `ALTER PROCEDURE [{schema}.]$SP_NAME`
   - File names matching `*$SP_NAME*.sql`
   - Migration files containing SP definition
   - Any `.sql` file containing the SP name

2. **If SP definition files exist** (from `Export-SpDefinitions.ps1` output):
   - Check `docs/sp-definitions/` for pre-exported .sql files
   - Check `scripts/sql/` or `db/` or `migrations/` folders

3. **If NOT found in repo**:
   - Tell the developer: "SP definition not found in the repository. Run the export script to extract it:"
   ```
   pwsh scripts/powershell/Export-SpDefinitions.ps1 -SpName "$SP_NAME" -OutputDir docs/sp-definitions/
   ```
   - Wait for the file to be available, then continue

Record: file path, line number, schema, SP name.

### Phase 2: Parse SP Logic

Read the SP definition and extract:

#### 2.1 Parameters
| Name | Type | Direction (IN/OUT/INOUT) | Default | Description [inferred] |
|------|------|--------------------------|---------|----------------------|

#### 2.2 Tables & Views Referenced
For each table/view:
| Object | Schema | Operations (SELECT/INSERT/UPDATE/DELETE) | JOIN type | Alias used |
|--------|--------|------------------------------------------|-----------|------------|

#### 2.3 Dynamic SQL Detection
- Flag any `EXEC(@sql)`, `sp_executesql`, string concatenation building SQL
- Extract the dynamic SQL template if possible
- Note which parameters feed into dynamic SQL (potential injection risk)

#### 2.4 Logic Branches
- Map conditional paths (IF/ELSE, CASE, WHERE with dynamic conditions)
- Identify distinct execution paths through the SP

#### 2.5 Other SP Calls
- List any `EXEC other_sp` or `INSERT INTO ... EXEC other_sp` patterns
- Flag recursive or chained SP dependencies

#### 2.6 Temp Tables / Table Variables
- List any `#temp`, `@table` variables
- Note their lifecycle within the SP

### Phase 3: Blast Radius Analysis

Search the .NET codebase for all invocation points:

#### 3.1 Direct References
Search for the SP name as a string literal across all .NET code:
- `"$SP_NAME"` in repository calls
- `CommandText = "...$SP_NAME..."` patterns
- Dapper calls: `.Query("$SP_NAME", ...)`, `.Execute("$SP_NAME", ...)`
- EF calls: `.FromSqlRaw("EXEC $SP_NAME ...")`
- ADO.NET: `SqlCommand("$SP_NAME")`
- Constants/enums that reference the SP name

#### 3.2 Call Chain Tracing
For each direct reference found:
1. Identify the containing method and class (Repository layer)
2. Find what calls that method (Service layer)
3. Find what calls the service (Controller/Handler layer)
4. Identify the HTTP endpoint or trigger (entry point)

Build the full chain: **HTTP Endpoint → Controller → Service → Repository → SP**

#### 3.3 Blast Radius Summary
| Level | Risk |
|-------|------|
| **Low** | Called from 1 place, single execution path |
| **Medium** | Called from 2-5 places, or has conditional logic paths |
| **High** | Called from 5+ places, or has dynamic SQL, or is called by other SPs |

### Phase 4: Documentation Generation

Generate documentation using the SP Analysis template (`templates/sp-analysis-template.md`).

Include:
- All sections from Phase 2 (parameters, tables, logic)
- Blast radius from Phase 3
- Mermaid diagrams:
  - **Execution flow** (flowchart showing SP logic branches)
  - **Invocation map** (sequence diagram showing .NET → SP call chain)
  - **ER diagram** (tables referenced by this SP)

Mark uncertain inferences:
- `[inferred]` — AI inferred from code, needs developer validation
- `[?]` — Unclear from code, needs investigation or runtime testing

### Phase 5: Change Preparation (if task type is bug fix or feature)

If the developer indicated they're modifying this SP:

1. **Pre-change validation script**: Generate a PowerShell script that captures current SP behavior:
   ```
   -- Captures current output for regression comparison
   EXEC $SP_NAME @param1 = 'value1', @param2 = 'value2'
   ```

2. **Regression risk assessment**: Based on blast radius, flag which .NET endpoints/features could be affected

3. **Test suggestions**: Propose xUnit test cases that should pass before and after the change

### Output

Save analysis to: `docs/sp-analysis/{schema}/{sp-name}.md`
Update SP registry: `docs/sp-analysis/_index.md`

### Quality Gates

Before completing, verify:
- [ ] SP definition located and parsed
- [ ] All parameters documented
- [ ] Tables and views listed with operations
- [ ] Dynamic SQL flagged (if present)
- [ ] .NET invocation points found
- [ ] Call chain traced to entry points
- [ ] Blast radius rated
- [ ] Mermaid diagrams render correctly
- [ ] Uncertain items flagged with `[inferred]` or `[?]`

### Defaults (for --quick mode)

- Task type: Understanding for modification
- Output: Full documentation
- Diagrams: Execution flow + Invocation map
- Skip all confirmation prompts
