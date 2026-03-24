---
name: neogov:workflow:sp-quick-fix
description: Guided SP fix mode — work through fixing a stored procedure issue step-by-step with the developer. Use when a developer says "I need to fix SP X, it has issue Y", "help me fix this stored procedure", "work with me on this SP problem", or describes a specific SP bug to resolve. This is the hands-on, interactive mode — not a full analysis dump, but a guided conversation.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git *), Bash(pwsh *), Bash(az *), Bash(docker *), Bash(sqlcmd *)
---

# Quick Fix — Guided SP Problem Solving

Interactive, guided mode for fixing a stored procedure issue. Unlike the full analysis skill (which generates comprehensive documentation), this skill works **with** the developer step-by-step through the fix process.

## When This Skill Triggers

- Developer says "I need to fix SP X, it has issue Y"
- Developer says "help me fix this stored procedure"
- Developer says "work with me through this SP problem"
- Developer describes a specific SP bug and wants to resolve it now
- Developer pastes an error message related to a stored procedure

## How This Differs from SP Analysis

| SP Analysis | SP Quick Fix |
|-------------|-------------|
| Generates full documentation | Focuses only on the problem area |
| Comprehensive blast radius | Targeted blast radius (only affected paths) |
| Outputs a complete analysis file | Outputs a fix + validation |
| Developer reads the output | Developer works through it interactively |

## Step 1: Understand the Problem (30 seconds)

Ask the developer concisely:

1. **Which SP?** — name or describe it
2. **What's the issue?** — error message, wrong result, performance, or behavior change
3. **How was it discovered?** — Jira ticket, testing, production incident, or someone reported it

Do NOT ask all three if the developer already provided context. Extract what you can from their initial message.

## Step 2: Quick Blast Radius (1-2 minutes)

Before touching the SP, do a **targeted** blast radius check:

1. Find the SP definition (repo files, `docs/sp-definitions/`, or MCP)
2. Search for .NET callers — but only trace the path relevant to the reported issue
3. Show a **concise** summary:

```
Blast radius for {SP name}:
  → {N} .NET callers found
  → Primary path: {Endpoint} → {Controller} → {Service} → {Repository}
  → Risk: {Low/Medium/High}

Safe to proceed? The change affects {description of impact scope}.
```

Wait for developer confirmation before proceeding.

## Step 3: Locate the Problem (guided)

Work with the developer to find the root cause:

1. Read the SP definition
2. Focus on the area described in the issue — don't analyze the entire SP
3. Show the relevant code section and explain what it does
4. Propose a hypothesis: "Based on what I see, the issue is likely {explanation}. Does that match what you're seeing?"
5. If the developer disagrees or wants to explore further, adjust

## Step 4: Propose the Fix

Show the specific change needed:

1. The exact lines to modify (before → after)
2. Why this fixes the issue
3. Any side effects flagged with `[inferred]` — "this might also affect {X}, please verify"
4. If the fix involves parameter changes, show the .NET callers that need updating

## Step 5: Generate Test Data

> **Key feature**: Help the developer test the fix locally before committing.

Generate sample parameter values for the SP based on its parameter definitions:

```powershell
# Test the SP with sample data — run BEFORE making the change
$params = @{
    CandidateId = 12345           # Sample int — use a real ID from your local DB
    DepartmentId = 1              # Typical department
    Status = 'Active'             # Common status value
    StartDate = '2026-01-01'      # Recent date
    PageSize = 50                 # Default page size
}

pwsh scripts/powershell/Test-SpChange.ps1 `
    -ServerInstance "localhost" -Database "AttractDB" `
    -SpName "{sp_name}" -Parameters $params -Phase "before"
```

For each parameter, provide:
- A realistic sample value based on the parameter type and name
- A comment explaining what realistic values look like
- If the SP uses lookups (FK references), suggest how to find valid IDs:
  ```sql
  -- Find a valid CandidateId to test with:
  SELECT TOP 5 CandidateId, Name FROM dbo.Candidates WHERE Status = 'Active'
  ```

## Step 6: Validate Together

After the developer makes the change:

1. Run the "after" snapshot:
   ```powershell
   pwsh scripts/powershell/Test-SpChange.ps1 ... -Phase "after"
   ```
2. Review the diff report together
3. Confirm: "The result set {changed as expected / has unexpected changes}"
4. If unexpected changes, help investigate

## Step 7: Wrap Up

- Update docs if the SP analysis exists: `docs/sp-analysis/{schema}/{sp-name}.md`
- Suggest: "Ready to commit? Use `/git:commit` to commit your changes."
- If the fix involved parameter changes, remind about .NET caller updates

## Quality Gate

- [ ] Problem understood (SP + issue + context)
- [ ] Blast radius checked (targeted, not full)
- [ ] Root cause identified with developer confirmation
- [ ] Fix proposed with side effects flagged
- [ ] Test data generated for local validation
- [ ] Before/after snapshots compared
- [ ] Developer confirmed fix is correct

## Composition

- May trigger `neogov:workflow:sp-analysis` if full analysis is needed (developer asks "actually, give me the full picture")
- Uses `Test-SpChange.ps1` for validation (always needed)
- References `/git:commit` for commit step — does NOT embed git logic
- Works alongside superpowers `systematic-debugging` — provides structured investigation
