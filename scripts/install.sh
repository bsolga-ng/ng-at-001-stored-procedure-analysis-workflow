#!/bin/bash
#
# Install SP Analysis workflow into a target repository
#
# Usage: ./install.sh /path/to/target-repo

set -e

TARGET_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== SP Analysis Workflow Installer ==="
echo "Source: $SCRIPT_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Create directories
mkdir -p "$TARGET_DIR/.claude/commands"
mkdir -p "$TARGET_DIR/.claude/skills"
mkdir -p "$TARGET_DIR/templates"
mkdir -p "$TARGET_DIR/scripts/powershell"
mkdir -p "$TARGET_DIR/docs/sp-analysis"
mkdir -p "$TARGET_DIR/docs/sp-definitions"
mkdir -p "$TARGET_DIR/docs/sp-metadata"

# Copy Claude Code command (onboarding only)
echo "Installing onboarding command..."
cp "$SCRIPT_DIR/.claude/commands/onboarding.md" "$TARGET_DIR/.claude/commands/"
echo "  Installed: /onboarding"

# Copy Claude Code skills (auto-triggering)
echo "Installing skills..."
cp -r "$SCRIPT_DIR/.claude/skills/"* "$TARGET_DIR/.claude/skills/"
echo "  Installed: sp-analysis, sp-change-prep, sp-discover, sp-document"

# Merge settings.local.json permissions
echo "Merging permissions..."
SETTINGS_FILE="$TARGET_DIR/.claude/settings.local.json"
SOURCE_SETTINGS="$SCRIPT_DIR/.claude/settings.local.json"

if [ ! -f "$SOURCE_SETTINGS" ]; then
    echo "  Skipped: no source settings.local.json found"
elif [ -f "$SETTINGS_FILE" ]; then
    # Target already has settings — merge permissions additively
    if command -v python3 &>/dev/null; then
        python3 - "$SETTINGS_FILE" "$SOURCE_SETTINGS" << 'PYEOF'
import json, sys

target_path = sys.argv[1]
source_path = sys.argv[2]

try:
    with open(target_path) as f:
        existing = json.load(f)
except (json.JSONDecodeError, FileNotFoundError) as e:
    print(f"  WARNING: Could not parse {target_path}: {e}")
    print("  Skipping merge — existing settings.local.json left unchanged.")
    sys.exit(0)

try:
    with open(source_path) as f:
        source = json.load(f)
except (json.JSONDecodeError, FileNotFoundError) as e:
    print(f"  WARNING: Could not parse {source_path}: {e}")
    sys.exit(0)

existing_perms = set(existing.get('permissions', {}).get('allow', []))
source_perms = set(source.get('permissions', {}).get('allow', []))
merged = sorted(existing_perms | source_perms)

existing.setdefault('permissions', {})['allow'] = merged

with open(target_path, 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')

added = source_perms - existing_perms
if added:
    print(f"  Merged {len(added)} new permission(s): {', '.join(sorted(added))}")
else:
    print("  All permissions already present — no changes needed")
PYEOF
    elif command -v node &>/dev/null; then
        # Fallback: use Node.js if python3 is unavailable (common on Windows)
        node -e "
const fs = require('fs');
const target = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
const source = JSON.parse(fs.readFileSync('$SOURCE_SETTINGS', 'utf8'));
const existing = new Set(target.permissions?.allow || []);
const toAdd = (source.permissions?.allow || []);
toAdd.forEach(p => existing.add(p));
if (!target.permissions) target.permissions = {};
target.permissions.allow = [...existing].sort();
fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(target, null, 2) + '\n');
console.log('  Merged permissions using Node.js');
"
    else
        echo "  WARNING: Neither python3 nor node found — cannot merge settings automatically."
        echo "  Please manually add these permissions to $SETTINGS_FILE:"
        cat "$SOURCE_SETTINGS"
    fi
else
    # No existing settings — just copy
    cp "$SOURCE_SETTINGS" "$SETTINGS_FILE"
    echo "  Installed settings.local.json"
fi

# Copy templates
echo "Installing templates..."
cp "$SCRIPT_DIR/templates/sp-analysis-template.md" "$TARGET_DIR/templates/"
echo "  Installed: sp-analysis-template.md"

# Copy PowerShell scripts
echo "Installing PowerShell scripts..."
cp "$SCRIPT_DIR/scripts/powershell/"*.ps1 "$TARGET_DIR/scripts/powershell/"
echo "  Installed: Export-SpDefinitions, Export-SpMetadata, Export-ExecutionPlan, Test-SpChange, Get-SpStats"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR && claude"
echo "  2. /onboarding                        — Interactive walkthrough"
echo "  3. Ask: 'What SPs does this codebase use?'  — SP discovery triggers automatically"
echo "  4. Ask: 'What does {sp-name} do?'    — SP analysis triggers automatically"
echo ""
echo "Skills installed (auto-trigger based on your task):"
echo "  sp-discover    — Builds SP registry when you explore SP references"
echo "  sp-analysis    — Full SP analysis when you ask about an SP"
echo "  sp-change-prep — Impact analysis when you plan to modify an SP"
echo "  sp-document    — Documentation when you ask to document SPs"
echo ""
echo "Optional: Run PowerShell scripts to export database data"
echo "  pwsh scripts/powershell/Export-SpDefinitions.ps1 -ServerInstance 'localhost' -Database 'YourDB'"
echo ""
echo "Alternative: If SQL Server MCP is enabled, skills query the database directly."
echo "  See docs/playbook.md → 'Level 2: SQL Server MCP Integration' for setup."
