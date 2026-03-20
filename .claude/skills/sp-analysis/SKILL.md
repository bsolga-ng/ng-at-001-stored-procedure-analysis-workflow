---
name: neogov:workflow:sp-analysis
description: Analyze SQL Server stored procedures — parse logic, parameters, dynamic SQL, dependencies, and trace .NET invocation points (blast radius). Use when a developer needs to understand a stored procedure before modifying it, is debugging a SP-related issue, wants to know the blast radius of changing an SP, or asks "what does this stored procedure do?". Generates Mermaid diagrams (execution flow, invocation map, ER) and structured documentation with [inferred] validation flags. Works with ADO.NET, Dapper, and Entity Framework codebases.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *), Bash(pwsh *)
---

# Analyze Stored Procedure

Full analysis of a stored procedure: parse logic, extract parameters, map dependencies, trace .NET invocation points (blast radius), and generate structured documentation.

## When This Skill Triggers

- Developer asks "what does {SP name} do?"
- Developer mentions modifying, debugging, or investigating a stored procedure
- Developer needs to understand blast radius before changing an SP
- Developer asks about SP dependencies, callers, or consumers
- Developer pastes SQL code containing stored procedure definitions
- Superpowers `systematic-debugging` identifies an SP as the root cause area

## Phase 1: Context Gathering

Determine the developer's intent from conversation context:

| Intent | Depth |
|--------|-------|
| Debugging a bug | Blast radius first, then targeted logic analysis |
| Optimizing performance | Blast radius first, then full logic analysis |
| Adding/modifying a feature | Blast radius first, then change prep (triggers `neogov:workflow:sp-change-prep`) |
| Understanding for knowledge transfer | Full documentation |
| Quick blast radius check | Blast radius only (Phase 3) — **default when intent is unclear** |

If intent is unclear, **default to blast radius first** — it's the highest-value output. A simple fix can have huge downstream impact; knowing the blast radius before anything else prevents surprises.

## Phase 2: Locate SP Definition

Search for the SP definition in the codebase:

1. **Search patterns** (in priority order):
   - `CREATE PROCEDURE [{schema}.]$SP_NAME` or `ALTER PROCEDURE [{schema}.]$SP_NAME`
   - File names matching `*$SP_NAME*.sql`
   - Migration files containing SP definition
   - Pre-exported files in `docs/sp-definitions/`

2. **If `microsoft-sql` MCP is available**: Query `OBJECT_DEFINITION()` directly from the database.

3. **If NOT found**:
   - Tell the developer: "SP definition not found. Run the export script or enable the microsoft-sql MCP server:"
   ```
   pwsh scripts/powershell/Export-SpDefinitions.ps1 -SpName "{SP_NAME}"
   ```
   - Wait for the file to be available, then continue

## Phase 3: Blast Radius Analysis (Priority Output)

> **This is the highest-value output.** Even a simple SP fix can have huge downstream impact. Always assess blast radius before diving into logic details.

Search the .NET codebase for all invocation points:

### 4.1 Direct References
Search for the SP name as a string literal across all .NET code:
- `"$SP_NAME"` in repository calls
- `CommandText = "...$SP_NAME..."` patterns
- Dapper: `.Query("$SP_NAME", ...)`, `.Execute("$SP_NAME", ...)`
- EF: `.FromSqlRaw("EXEC $SP_NAME ...")`
- ADO.NET: `SqlCommand("$SP_NAME")`
- Constants/enums referencing the SP name

### 4.2 Call Chain Tracing
For each direct reference:
1. Repository layer → method and class containing the SP call
2. Service layer → what calls the repository method
3. Controller layer → what calls the service method
4. Entry point → HTTP endpoint, Azure Function trigger, background job, or message handler

Build: **HTTP Endpoint → Controller → Service → Repository → SP**

### 4.3 Cross-SP Dependencies
- SPs that call this SP (`EXEC $SP_NAME` in other .sql files)
- SPs this SP calls
- Shared tables with other SPs

### 4.4 Blast Radius Rating
| Level | Criteria |
|-------|----------|
| **Low** | 1 caller, single execution path |
| **Medium** | 2-5 callers, or conditional logic paths |
| **High** | 5+ callers, dynamic SQL, or called by other SPs |

## Phase 4: Parse SP Logic

Read the SP definition and extract:

### 4.1 Parameters
| Name | Type | Direction (IN/OUT) | Default | Description [inferred] |

### 4.2 Tables & Views Referenced
| Object | Schema | Operations (SELECT/INSERT/UPDATE/DELETE) | JOIN type | Notes |

### 4.3 Dynamic SQL Detection
- Flag `EXEC(@sql)`, `sp_executesql`, string concatenation building SQL
- Extract the dynamic SQL template if possible
- Note parameters feeding into dynamic SQL (injection risk)

### 4.4 Logic Branches
- Map conditional paths (IF/ELSE, CASE, WHERE with dynamic conditions)
- Identify distinct execution paths through the SP

### 4.5 Other SP Calls
- List `EXEC other_sp` or `INSERT INTO ... EXEC other_sp` patterns
- Flag recursive or chained SP dependencies

### 4.6 Temp Tables / Table Variables
- List `#temp`, `@table` variables with lifecycle

## Phase 5: Documentation Generation

Generate documentation using the analysis template (see `references/analysis-template.md`).

Include Mermaid diagrams:
- **Execution flow** — flowchart showing SP logic branches
- **Invocation map** — sequence diagram showing .NET → SP call chain
- **ER diagram** — tables referenced by this SP

Mark uncertain inferences:
- `[inferred]` — AI inferred from code, needs developer validation
- `[?]` — Unclear from code, needs investigation or runtime testing
- `[validated]` — Confirmed by developer (added during review)

## Phase 6: Next Step Recommendation

Based on the developer's intent:
- **Modifying**: "Run the change preparation workflow to assess impact and generate validation scripts" (triggers `neogov:workflow:sp-change-prep`)
- **Documenting**: Save to `docs/sp-analysis/{schema}/{sp-name}.md` and update registry
- **Debugging**: Highlight the relevant execution paths and suggest investigation points
- **Understanding**: Present the analysis and offer to deep-dive into any section

## Output

Save analysis to: `docs/sp-analysis/{schema}/{sp-name}.md`
Update SP registry: `docs/sp-analysis/_index.md`

## Quality Gate

- [ ] SP definition located and parsed
- [ ] All parameters documented
- [ ] Tables and views listed with operations
- [ ] Dynamic SQL flagged (if present)
- [ ] .NET invocation points found
- [ ] Call chains traced to entry points
- [ ] Blast radius rated
- [ ] Mermaid diagrams render correctly
- [ ] Uncertain items flagged with `[inferred]` or `[?]`

## Composition

- Consumes registry from `neogov:workflow:sp-discover` (auto-triggers discover if no registry exists)
- Feeds into `neogov:workflow:sp-change-prep` when developer intends to modify
- Feeds into `neogov:workflow:sp-document` for documentation updates
- Works alongside superpowers `systematic-debugging` — provides SP context for root-cause analysis
- Does NOT generate git commits — developer uses `/git:commit` when ready
- Does NOT replace superpowers `verification-before-completion` — analysis outputs are verifiable artifacts
