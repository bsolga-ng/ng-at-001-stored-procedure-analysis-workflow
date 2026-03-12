---
command: onboarding
description: Interactive walkthrough of the SP analysis workflow
creation-date: 2026-03-11 20:00 UTC+0200
last-update: 2026-03-11 21:00 UTC+0200
---

# Onboarding — SP Analysis Workflow

Welcome to the Stored Procedure Analysis workflow. This guide walks you through the available commands and how they fit into your development process.

## Instructions

Present this information interactively, adapting to the developer's experience level.

### Introduction

"This workflow helps you understand, document, and safely modify stored procedures. It works by analyzing SP source code from your repository and tracing how your .NET code invokes each SP.

**What it can do:**
- Parse SP logic (parameters, tables, JOINs, dynamic SQL)
- Find every .NET code path that calls a given SP (blast radius)
- Generate structured documentation with Mermaid diagrams
- Prepare impact analysis and validation scripts before you make changes

**What it needs from you:**
- SP definitions as `.sql` files in the repo (or exported via PowerShell scripts)
- Your .NET codebase in the same repository (or accessible path)

**What it can't do (and the workarounds):**
- Can't connect to databases — use the PowerShell scripts to export data
- Can't execute SPs — use the validation scripts to capture before/after snapshots
- Can't read live execution plans — export them from SSMS and paste for analysis"

### Workflow Overview

Present the typical developer workflow:

```
1. DISCOVER          /sp-discover src
   Build SP registry (run once, update periodically)
        |
2. ANALYZE           /sp-analyze {sp-name}
   Deep-dive when assigned an SP task
        |
3. CHANGE PREP       /sp-change-prep {sp-name}
   Before modifying — impact analysis + validation scripts
        |
4. (Make the change)  Developer modifies SP
        |
5. VALIDATE          Run Test-SpChange.ps1 --Phase after
   Compare before/after snapshots
        |
6. UPDATE DOCS       /sp-document {sp-name} --refresh
   Keep docs current
```

### Interactive Demo

Offer to demonstrate:

"Would you like me to:
1. **Run discovery** on your codebase to find all SP references
2. **Analyze a specific SP** you're working on right now
3. **Show you the PowerShell scripts** for database interaction
4. **Just show the command list** and let you explore on your own"

Proceed based on the developer's choice.
