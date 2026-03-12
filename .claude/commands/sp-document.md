---
command: sp-document
description: Generate or update structured documentation for a stored procedure
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-11 20:00 UTC+0200
---

# Document Stored Procedure

Generate structured documentation for a stored procedure, or batch-document multiple SPs.

## Arguments
- `$ARGUMENTS` - SP name, `--batch`, or `--coverage`

## Instructions

### Parse Arguments

- SP name → Document single SP
- `--batch {pattern}` → Document all SPs matching pattern (e.g., `--batch DataSync.*`)
- `--coverage` → Report documentation coverage stats
- `--refresh {sp-name}` → Re-generate docs for an SP (overwrites existing)

### Single SP Documentation

1. Check if `/sp-analyze` has already been run for this SP:
   - If `docs/sp-analysis/{schema}/{sp-name}.md` exists, refresh it
   - If not, run the full analysis pipeline (Phase 1-4 of `/sp-analyze`)

2. Generate documentation using `templates/sp-analysis-template.md`

3. Save to `docs/sp-analysis/{schema}/{sp-name}.md`

4. Update registry `docs/sp-analysis/_index.md`

### Batch Documentation

For `--batch {pattern}`:

1. Find all SPs matching the pattern in the registry
2. For each SP, run documentation generation
3. Report progress: `[N/Total] Documenting {sp-name}...`
4. Generate batch summary:

```markdown
# Batch Documentation Report

| SP Name | Status | Complexity | Notes |
|---------|--------|------------|-------|
| {name} | Generated | {S/M/L} | {any issues} |
```

### Coverage Report

For `--coverage`:

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

### Quality Gate

| Criterion | Pass |
|-----------|------|
| Documentation follows template | [ ] |
| All Mermaid diagrams render | [ ] |
| Registry updated | [ ] |
| Uncertain items flagged | [ ] |
