#!/bin/bash
# Install SDM (Raspberry Pi SD Card Image Management tool)
# https://github.com/gitbls/sdm

set -e
set -u
set -o pipefail

# Configuration
readonly SDM_DIR="$HOME/.local/sdm"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}Error: This script is designed for Linux (Ubuntu)${NC}"
    exit 1
fi

# Check if SDM is already installed
if command -v sdm >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SDM is already installed${NC}"
    echo "Version: $(sdm --version 2>&1 | head -1)"
    echo "Location: $(which sdm)"
    exit 0
fi

echo -e "${YELLOW}Installing SDM...${NC}"

# Install SDM dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update
sudo apt-get install -y \
    systemd-container \
    qemu-user-static \
    binfmt-support \
    git \
    curl \
    xz-utils \
    pv \
    jq

# Remove old installation if it exists
if [ -d "$SDM_DIR" ]; then
    echo -e "${YELLOW}Removing old SDM installation...${NC}"
    rm -rf "$SDM_DIR"
fi

# Clone SDM repository
echo -e "${YELLOW}Cloning SDM repository...${NC}"
git clone https://github.com/gitbls/sdm.git "$SDM_DIR"

# Create symlink
echo -e "${YELLOW}Creating symlink...${NC}"
sudo ln -sf "$SDM_DIR/sdm" /usr/local/bin/sdm

# Verify installation
if command -v sdm >/dev/null 2>&1; then
    echo -e "${GREEN}✓ SDM installed successfully!${NC}"
    echo "Version: $(sdm --version 2>&1 | head -1)"
    echo "Location: $(which sdm)"
else
    echo -e "${RED}Error: SDM installation failed${NC}"
    exit 1
fi

echo ""
echo "SDM is now ready to use!"
echo "For documentation, see: https://github.com/gitbls/sdm/wiki"