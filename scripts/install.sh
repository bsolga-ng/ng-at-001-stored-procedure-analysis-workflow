#!/bin/bash
#
# Install SP Analysis workflow commands into a target repository
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
mkdir -p "$TARGET_DIR/templates"
mkdir -p "$TARGET_DIR/scripts/powershell"
mkdir -p "$TARGET_DIR/docs/sp-analysis"
mkdir -p "$TARGET_DIR/docs/sp-definitions"
mkdir -p "$TARGET_DIR/docs/sp-metadata"

# Copy Claude Code commands
echo "Installing Claude Code commands..."
cp -r "$SCRIPT_DIR/.claude/commands/"* "$TARGET_DIR/.claude/commands/"
echo "  Installed: onboarding, sp-analyze, sp-discover, sp-blast-radius, sp-document, sp-change-prep"

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
echo "  3. /sp-discover src                   — Build SP registry"
echo "  4. /sp-analyze {sp-name}              — Analyze a stored procedure"
echo ""
echo "Optional: Run PowerShell scripts to export database data"
echo "  pwsh scripts/powershell/Export-SpDefinitions.ps1 -ServerInstance 'localhost' -Database 'YourDB'"
echo "  pwsh scripts/powershell/Export-SpMetadata.ps1 -ServerInstance 'localhost' -Database 'YourDB'"
