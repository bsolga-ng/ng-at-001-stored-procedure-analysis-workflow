---
name: neogov:workflow:sp-document
description: Generate or update structured documentation for SQL Server stored procedures with Mermaid diagrams. Use when a developer asks to document an SP, requests SP documentation coverage stats, when sp-analysis completes and documentation needs saving, or when batch-documenting multiple procedures. Supports single SP, batch (pattern matching), coverage audit, and refresh modes.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *)
---

# Document Stored Procedure

Generate structured documentation for a stored procedure using the analysis template, or audit documentation coverage across the SP registry.

## When This Skill Triggers

- Developer asks to "document this SP" or "generate SP docs"
- Developer asks "how many SPs are documented?" or "which SPs are undocumented?"
- `neogov:workflow:sp-analysis` completes and the developer wants to save documentation
- `neogov:workflow:sp-change-prep` checklist reaches the documentation update step
- Developer asks to batch-document SPs by pattern (e.g., "document all DataSync SPs")

## Modes

Determine mode from conversation context:

| Context | Mode |
|---------|------|
| Developer mentions a specific SP name | **Single SP** — document that SP |
| Developer mentions a pattern or "all" | **Batch** — document matching SPs |
| Developer asks about coverage or completeness | **Coverage** — report documentation stats |
| Developer says "refresh" or "update docs" | **Refresh** — re-generate existing docs |

## Single SP Documentation

1. Check if analysis exists at `docs/sp-analysis/{schema}/{sp-name}.md`
   - If exists: Refresh with latest analysis data
   - If not: Trigger `neogov:workflow:sp-analysis` first

2. Generate documentation using the analysis template (see `references/analysis-template.md`)

3. Save to `docs/sp-analysis/{schema}/{sp-name}.md`

4. Update registry `docs/sp-analysis/_index.md`

## Batch Documentation

For a pattern (e.g., "DataSync.*"):

1. Find all matching SPs in the registry (`docs/sp-analysis/_index.md`)
2. For each SP, run documentation generation
3. Report progress: `[N/Total] Documenting {sp-name}...`
4. Generate batch summary:

```markdown
# Batch Documentation Report

| SP Name | Status | Complexity | Notes |
|---------|--------|------------|-------|
| {name} | Generated | {S/M/L} | {any issues} |
```

## Coverage Report

```markdown
# SP Documentation Coverage

| Status | Count | Percentage |
|--------|-------|------------|
| Documented | {N} | {%} |
| Missing | {N} | {%} |
| Stale (>30 days) | {N} | {%} |

## Undocumented SPs (by reference count)

| SP Name | .NET References | Priority |
|---------|-----------------|----------|
| {name} | {N} | {High if >3 refs} |
```

## Quality Gate

- [ ] Documentation follows analysis template
- [ ] All Mermaid diagrams render correctly
- [ ] Registry `_index.md` updated
- [ ] Uncertain items flagged with `[inferred]` or `[?]`

## Composition

- Requires `neogov:workflow:sp-analysis` output (auto-triggers if no analysis exists)
- Consumes registry from `neogov:workflow:sp-discover`
- Uses `references/analysis-template.md` for documentation structure
- Does NOT generate git commits — developer uses `/git:commit` when ready
- Batch mode works within a single session — does NOT dispatch parallel agents (SPs share code context)
