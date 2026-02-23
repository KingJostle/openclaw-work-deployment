#!/bin/bash
# setup-work-openclaw.sh
# Sets up work OpenClaw environment using proven personal patterns

set -e

WORK_WORKSPACE="${1:-$HOME/.openclaw-work/workspace}"
PERSONAL_WORKSPACE="$HOME/.openclaw/workspace"

echo "🏢 Setting up work OpenClaw environment..."
echo "Work workspace: $WORK_WORKSPACE"
echo "Source patterns: $PERSONAL_WORKSPACE"

# Create work workspace structure
mkdir -p "$WORK_WORKSPACE"/{memory,scripts,tools}

# Phase 1: Direct framework transfers
echo "[1/4] Transferring core framework..."

# Rate limit monitoring (proven system)
cp "$PERSONAL_WORKSPACE/memory/rate-limit-"*.md "$WORK_WORKSPACE/memory/"
echo "  ✅ Rate limit monitoring system"

# Backup framework (needs path adaptation)
cp "$PERSONAL_WORKSPACE/openclaw-backup.sh" "$WORK_WORKSPACE/"
cp "$PERSONAL_WORKSPACE/openclaw-restore-runbook.md" "$WORK_WORKSPACE/"
echo "  ✅ Backup framework (requires path customization)"

# Phase 2: Template files with customization needed
echo "[2/4] Installing work templates..."

# Use templates from this directory
TEMPLATE_DIR="$(dirname "$0")/.."
cp "$TEMPLATE_DIR"/*.md "$WORK_WORKSPACE/"
echo "  ✅ Core template files (require customization)"

# Phase 3: Initialize memory structure  
echo "[3/4] Initializing work memory..."

# Create today's memory file
TODAY=$(date +%Y-%m-%d)
cat > "$WORK_WORKSPACE/memory/$TODAY.md" << EOF
# $TODAY - Work Context

## Setup
- Work OpenClaw environment initialized
- Templates installed, need customization
- Rate limit monitoring system active

## Next Steps
- Complete BOOTSTRAP.md checklist
- Populate USER.md with actual work context
- Configure work-specific authentication
- Test core workflows

EOF
echo "  ✅ Initial memory file: $TODAY.md"

# Phase 4: Create customization checklist
echo "[4/4] Creating setup checklist..."

cat > "$WORK_WORKSPACE/SETUP-STATUS.md" << EOF
# Work OpenClaw Setup Status

## Framework Transfer: ✅ Complete
- [x] Rate limit monitoring system
- [x] Backup framework  
- [x] Core template files
- [x] Memory structure

## Customization Required: 🔄 In Progress
- [ ] USER.md - Add your company context
- [ ] IDENTITY.md - Choose work assistant persona
- [ ] TOOLS.md - Add work infrastructure  
- [ ] MEMORY.md - Add stakeholder context
- [ ] HEARTBEAT.md - Set work hours/monitoring

## Security Setup: ⏸️ Pending
- [ ] Work-specific credential storage
- [ ] Data isolation verification
- [ ] Backup location for work environment
- [ ] Access control review

## Testing: ⏸️ Pending  
- [ ] Session startup sequence
- [ ] Heartbeat monitoring (work hours)
- [ ] Rate limit system
- [ ] Communication workflows

## Next Actions
1. Follow BOOTSTRAP.md checklist
2. Complete customization section
3. Set up work-specific authentication
4. Test with actual work scenarios

EOF

echo ""
echo "🎯 Setup complete! Next steps:"
echo "1. cd $WORK_WORKSPACE"
echo "2. Follow BOOTSTRAP.md checklist"
echo "3. Customize template files for your work environment"
echo "4. Review SETUP-STATUS.md for progress tracking"
echo ""
echo "💡 Your proven patterns are preserved, work context starts fresh."