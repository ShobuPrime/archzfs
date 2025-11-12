#!/bin/bash
#
# build-openzfs-version.sh - Build archzfs packages for any OpenZFS version
#
# Usage: ./build-openzfs-version.sh <version> [stable|rc]
# Example: ./build-openzfs-version.sh 2.4.0-rc3 rc
# Example: ./build-openzfs-version.sh 2.3.5 stable
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Usage: sudo $0 <version> [stable|rc]"
   exit 1
fi

# Parse arguments
VERSION=$1
TYPE=${2:-rc}  # Default to 'rc' if not specified

if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: Version argument required${NC}"
    echo "Usage: $0 <version> [stable|rc]"
    echo ""
    echo "Examples:"
    echo "  $0 2.4.0-rc3 rc"
    echo "  $0 2.3.5 stable"
    exit 1
fi

# Validate type
if [[ "$TYPE" != "stable" && "$TYPE" != "rc" ]]; then
    echo -e "${RED}Error: Type must be 'stable' or 'rc'${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building OpenZFS $VERSION ($TYPE)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Download tarball and compute hash
echo -e "${GREEN}[1/5] Downloading OpenZFS $VERSION and computing SHA256 hash...${NC}"
TARBALL_URL="https://github.com/openzfs/zfs/releases/download/zfs-${VERSION}/zfs-${VERSION}.tar.gz"
TEMP_DIR=$(mktemp -d)
TARBALL_PATH="$TEMP_DIR/zfs-${VERSION}.tar.gz"

if ! wget -q -O "$TARBALL_PATH" "$TARBALL_URL"; then
    echo -e "${RED}Error: Failed to download $TARBALL_URL${NC}"
    echo "Please verify the version exists at: https://github.com/openzfs/zfs/releases"
    rm -rf "$TEMP_DIR"
    exit 1
fi

HASH=$(sha256sum "$TARBALL_PATH" | awk '{print $1}')
echo -e "${GREEN}  SHA256: $HASH${NC}"
rm -rf "$TEMP_DIR"

# Step 2: Update conf.sh
echo -e "${GREEN}[2/5] Updating conf.sh...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/conf.sh"

if [[ ! -f "$CONF_FILE" ]]; then
    echo -e "${RED}Error: conf.sh not found at $CONF_FILE${NC}"
    exit 1
fi

if [[ "$TYPE" == "stable" ]]; then
    # Update stable version
    sed -i "s/^openzfs_version=.*/openzfs_version=\"$VERSION\"/" "$CONF_FILE"
    sed -i "s/^zfs_src_hash=.*/zfs_src_hash=\"$HASH\"/" "$CONF_FILE"
    echo -e "${GREEN}  Updated openzfs_version and zfs_src_hash${NC}"
elif [[ "$TYPE" == "rc" ]]; then
    # Update RC version
    sed -i "s/^openzfs_rc_version=.*/openzfs_rc_version=\"$VERSION\"/" "$CONF_FILE"
    sed -i "s/^zfs_rc_src_hash=.*/zfs_rc_src_hash=\"$HASH\"/" "$CONF_FILE"
    echo -e "${GREEN}  Updated openzfs_rc_version and zfs_rc_src_hash${NC}"
fi

# Step 3: Generate PKGBUILDs
echo -e "${GREEN}[3/5] Generating PKGBUILDs...${NC}"
echo -e "${YELLOW}  Generating utils PKGBUILD...${NC}"
"$SCRIPT_DIR/build.sh" utils update 2>&1 | grep -E "(===|Error|Created)" || true

echo -e "${YELLOW}  Generating dkms PKGBUILD...${NC}"
"$SCRIPT_DIR/build.sh" dkms update 2>&1 | grep -E "(===|Error|Created)" || true

# Step 4: Verify generated PKGBUILDs
echo -e "${GREEN}[4/5] Verifying generated PKGBUILDs...${NC}"

if [[ "$TYPE" == "stable" ]]; then
    UTILS_PKGBUILD="$SCRIPT_DIR/packages/_utils/zfs-utils/PKGBUILD"
    DKMS_PKGBUILD="$SCRIPT_DIR/packages/dkms/zfs-dkms/PKGBUILD"
else
    UTILS_PKGBUILD="$SCRIPT_DIR/packages/_utils/zfs-utils-rc/PKGBUILD"
    DKMS_PKGBUILD="$SCRIPT_DIR/packages/dkms/zfs-dkms-rc/PKGBUILD"
fi

if [[ -f "$UTILS_PKGBUILD" ]]; then
    UTILS_VER=$(grep "^pkgver=" "$UTILS_PKGBUILD" | cut -d= -f2)
    UTILS_HASH=$(grep "^sha256sums=" "$UTILS_PKGBUILD" | grep -oP '"\K[^"]+' | head -1)
    echo -e "${GREEN}  Utils PKGBUILD: pkgver=$UTILS_VER, hash=${UTILS_HASH:0:16}...${NC}"
else
    echo -e "${RED}  Error: Utils PKGBUILD not found at $UTILS_PKGBUILD${NC}"
fi

if [[ -f "$DKMS_PKGBUILD" ]]; then
    DKMS_VER=$(grep "^pkgver=" "$DKMS_PKGBUILD" | cut -d= -f2)
    DKMS_HASH=$(grep "^sha256sums=" "$DKMS_PKGBUILD" | grep -oP '"\K[^"]+' | head -1)
    echo -e "${GREEN}  DKMS PKGBUILD: pkgver=$DKMS_VER, hash=${DKMS_HASH:0:16}...${NC}"
else
    echo -e "${RED}  Error: DKMS PKGBUILD not found at $DKMS_PKGBUILD${NC}"
fi

# Step 5: Provide build instructions
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}[5/5] PKGBUILDs generated successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps to build packages:${NC}"
echo ""
echo "  1. Build utilities package:"
echo "     sudo ./build.sh utils make -u"
echo ""
echo "  2. Build DKMS package:"
echo "     sudo ./build.sh dkms make -u"
echo ""
echo "  The -u flag updates the clean chroot before building."
echo ""
echo -e "${YELLOW}Package locations (after build):${NC}"
if [[ "$TYPE" == "stable" ]]; then
    echo "  $SCRIPT_DIR/packages/_utils/zfs-utils/*.pkg.tar.zst"
    echo "  $SCRIPT_DIR/packages/dkms/zfs-dkms/*.pkg.tar.zst"
else
    echo "  $SCRIPT_DIR/packages/_utils/zfs-utils-rc/*.pkg.tar.zst"
    echo "  $SCRIPT_DIR/packages/dkms/zfs-dkms-rc/*.pkg.tar.zst"
fi
echo ""
echo -e "${YELLOW}Installation:${NC}"
echo "  sudo pacman -U path/to/zfs-utils*.pkg.tar.zst"
echo "  sudo pacman -U path/to/zfs-dkms*.pkg.tar.zst"
echo ""
