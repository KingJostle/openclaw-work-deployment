#!/bin/bash
# reset-workspace.sh
# Resets workspace to default templates from the deployment repo

set -e

WORKSPACE_DIR="${1:-$HOME/.openclaw-work/workspace}"

echo "🔄 Resetting workspace to default templates..."
echo "Workspace: $WORKSPACE_DIR"

if [[ -d "$WORKSPACE_DIR" ]]; then
    echo ""
    read -p "⚠️  This will overwrite template files (memory/ is preserved). Continue? (y/N) " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Create structure
mkdir -p "$WORKSPACE_DIR"/{memory,scripts,tools}

# Find template source (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Copy core templates
echo "[1/3] Copying template files..."
for file in AGENTS.md SOUL.md USER.md IDENTITY.md TOOLS.md MEMORY.md HEARTBEAT.md BOOTSTRAP.md; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        cp "$SCRIPT_DIR/$file" "$WORKSPACE_DIR/"
        echo "  ✅ $file"
    fi
done

# Copy rate limit system (only if memory dir has no user content)
echo "[2/3] Checking rate limit monitoring..."
if [[ -d "$SCRIPT_DIR/memory" ]]; then
    for rl in "$SCRIPT_DIR"/memory/rate-limit-*.md; do
        [[ -f "$rl" ]] && cp "$rl" "$WORKSPACE_DIR/memory/"
    done
    echo "  ✅ Rate limit monitoring files"
fi

# Copy docs
echo "[3/3] Copying documentation..."
for doc in SETUP-GUIDE.md TRANSFER-SUMMARY.md; do
    if [[ -f "$SCRIPT_DIR/$doc" ]]; then
        cp "$SCRIPT_DIR/$doc" "$WORKSPACE_DIR/"
    fi
done

# Initialize today's memory if it doesn't exist
TODAY=$(date +%Y-%m-%d)
if [[ ! -f "$WORKSPACE_DIR/memory/$TODAY.md" ]]; then
    cat > "$WORKSPACE_DIR/memory/$TODAY.md" << EOF
# $TODAY

## Setup
- Workspace initialized/reset from templates
- Customize USER.md, IDENTITY.md, MEMORY.md, TOOLS.md, HEARTBEAT.md
- Follow BOOTSTRAP.md checklist
EOF
    echo "  ✅ Created memory/$TODAY.md"
fi

echo ""
echo "✅ Workspace reset complete!"
echo ""
echo "Next steps:"
echo "  1. cd $WORKSPACE_DIR"
echo "  2. Follow BOOTSTRAP.md checklist"
echo "  3. Customize template files for your environment"
