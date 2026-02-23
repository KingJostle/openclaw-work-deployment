#!/bin/bash
# OpenClaw Work Environment - One-Command Installation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🦞 OpenClaw Work Environment - Quick Install${NC}"
echo ""
echo "This will install and configure OpenClaw for your work environment."
echo "Installation includes: Node.js, OpenClaw, systemd service, and work templates."
echo ""
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read -r

# Run the main installation
echo -e "${GREEN}Starting installation...${NC}"
echo ""

./install.sh

echo ""
echo -e "${GREEN}Running verification checks...${NC}"
echo ""

# Give the service a moment to start
sleep 5

./verify-install.sh

echo ""
echo -e "${BLUE}📚 Quick Start Guide:${NC}"
echo "1. Open: http://localhost:18789"
echo "2. Navigate to workspace: openclaw-work"
echo "3. Follow BOOTSTRAP.md to customize for your work"
echo ""
echo -e "${GREEN}Installation complete! 🎉${NC}"