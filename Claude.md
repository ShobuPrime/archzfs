# Building OpenZFS DKMS Packages for Arch Linux

**Project**: archzfs - Building OpenZFS DKMS packages for any Arch Linux kernel
**Repository**: https://github.com/archzfs/archzfs

## Executive Summary

This guide documents how to build OpenZFS DKMS packages from the archzfs build system for Arch Linux. It includes critical fixes for RC (release candidate) builds, a helper script for building any OpenZFS version, and troubleshooting steps for common issues.

---

## Problem Statement

### Why This Guide Exists
- **Issue**: Arch Linux's rolling release kernel updates can break compatibility with stable ZFS packages
- **Solution**: Build DKMS versions of OpenZFS (stable or RC) that work with your current kernel
- **Repository**: archzfs provides templates and build scripts for Arch Linux ZFS packages

### Why DKMS?
DKMS (Dynamic Kernel Module Support) packages are kernel-independent. They:
- Automatically compile modules when you install or upgrade kernels
- Don't require rebuilding for each kernel version
- Provide better compatibility across kernel updates

---

## Configuration Changes Made

### 1. Version Configuration (`conf.sh`)

**File**: [conf.sh](conf.sh)

```bash
# Updated from 2.4.0-rc1 to 2.4.0-rc3
openzfs_rc_version="2.4.0-rc3"
zfs_rc_src_hash="396204a7b03cfc7e8623b9d64f3e26a9d213525c5af492fbdbb705f0bbe65ddc"
```

**How we got the hash**:
```bash
wget https://github.com/openzfs/zfs/releases/download/zfs-2.4.0-rc3/zfs-2.4.0-rc3.tar.gz
sha256sum zfs-2.4.0-rc3.tar.gz
```

### 2. Enable RC Builds for DKMS (`src/kernels/dkms.sh`)

**File**: [src/kernels/dkms.sh](src/kernels/dkms.sh#L40-L53)

**Change**: Uncommented the `update_dkms_rc_pkgbuilds()` function

**Critical Fix Applied**: Changed workdir path from:
```bash
zfs_workdir="\${srcdir}/zfs-\${pkgver/_rc*/}"  # WRONG - strips rc suffix
```
To:
```bash
zfs_workdir="\${srcdir}/zfs-\${pkgver/_/-}"    # CORRECT - keeps full version
```

**Why this matters**: The tarball extracts as `zfs-2.4.0-rc3/`, not `zfs-2.4.0/`. The original regex pattern `/_rc*/` was stripping the RC suffix, causing the build to fail with "directory not found" errors.

### 3. Enable RC Builds for Utils (`src/kernels/_utils.sh`)

**File**: [src/kernels/_utils.sh](src/kernels/_utils.sh#L38-L49)

**Change**: Uncommented the `update_utils_rc_pkgbuilds()` function with the same workdir fix applied.

### 4. Fix initcpio Hook Paths (`src/zfs-utils/zfs-utils.initcpio.install`)

**File**: [src/zfs-utils/zfs-utils.initcpio.install](src/zfs-utils/zfs-utils.initcpio.install)

**Critical Fix Applied**: Updated all paths from `/lib/` to `/usr/lib/` for modern Arch Linux compatibility:

```bash
# Changed from:
/lib/udev/vdev_id
/lib/udev/zvol_id
/lib/udev/rules.d/60-zvol.rules
/lib/udev/rules.d/69-vdev.rules
/lib/udev/rules.d/90-zfs.rules
/lib/libgcc_s.so.1

# To:
/usr/lib/udev/vdev_id
/usr/lib/udev/zvol_id
/usr/lib/udev/rules.d/60-zvol.rules
/usr/lib/udev/rules.d/69-vdev.rules
/usr/lib/udev/rules.d/90-zfs.rules
/usr/lib/libgcc_s.so.1
```

**Updated hash in conf.sh**:
```bash
zfs_initcpio_install_hash="1e8c13ced9dc9696565cd232fcf8d8b6ecbe45dcb594bef13b4a9bfeb0ce02b6"
```

**Why this matters**: Modern Arch Linux uses `/usr/lib` exclusively. The `/lib` directory is now a symlink to `usr/lib`. The old hardcoded `/lib/` paths would cause mkinitcpio errors during installation.

---

## Build Process

### Prerequisites
```bash
# Install required build dependencies
sudo pacman -S base-devel python python-setuptools python-cffi dkms
```

### Step-by-Step Build

1. **Update Configuration**
   ```bash
   # Already done - conf.sh updated with 2.4.0-rc3 and hash
   ```

2. **Generate PKGBUILDs**
   ```bash
   sudo ./build.sh utils update
   sudo ./build.sh dkms update
   ```

   **Generated Files**:
   - `packages/_utils/zfs-utils-rc/PKGBUILD`
   - `packages/dkms/zfs-dkms-rc/PKGBUILD`

3. **Build Packages Directly with makepkg**

   Since the build.sh script requires `ccm` (clean-chroot-manager) which wasn't available, we built directly:

   ```bash
   # Build zfs-utils-rc
   cd packages/_utils/zfs-utils-rc
   makepkg -s --noconfirm

   # Build zfs-dkms-rc (skip deps since utils not yet installed)
   cd packages/dkms/zfs-dkms-rc
   makepkg -s --nodeps --noconfirm
   ```

### Build Results

**Package Locations**:
```
packages/_utils/zfs-utils-rc/zfs-utils-rc-<VERSION>-1-x86_64.pkg.tar.zst
packages/dkms/zfs-dkms-rc/zfs-dkms-rc-<VERSION>-1-x86_64.pkg.tar.zst
```

**Typical Sizes**: ~30-35 MB each

**Verify Checksums**:
```bash
sha256sum packages/_utils/zfs-utils-rc/*.pkg.tar.zst
sha256sum packages/dkms/zfs-dkms-rc/*.pkg.tar.zst
```

---

## Installation

### Installing the Built Packages

```bash
# Remove old ZFS packages (if any)
sudo pacman -R zfs-dkms zfs-utils

# Install new RC packages (use actual filenames from your build)
sudo pacman -U \
  packages/_utils/zfs-utils-rc/zfs-utils-rc-*.pkg.tar.zst \
  packages/dkms/zfs-dkms-rc/zfs-dkms-rc-*.pkg.tar.zst
```

### Post-Installation (No Manual Fixes Required)

**✅ Fixed**: The initcpio hook paths have been permanently fixed in the source templates. Packages built from this repository now automatically include the correct `/usr/lib/` paths.

**Note**: If you previously installed packages before this fix (November 2025), the paths are now correct and mkinitcpio should work without errors. The fix is built into all new packages.

### Verification

```bash
# Check ZFS version
zfs --version

# Check DKMS status
dkms status | grep zfs

# Check kernel module
modinfo zfs | head -5

# List installed packages
pacman -Q | grep zfs
```

**Expected output** should show your installed version and kernel module built for your current kernel.

---

## Lessons Learned

### 1. Workdir Path Pattern Issue

**Problem**: Original RC configuration used `zfs_workdir="\${srcdir}/zfs-\${pkgver/_rc*/}"`

**Root Cause**: The bash pattern `/_rc*/` strips everything from `_rc` onwards, converting `2.4.0_rc3` to `2.4.0`. However, the source tarball extracts to `zfs-2.4.0-rc3/` (with hyphen, not underscore).

**Solution**: Changed to `zfs_workdir="\${srcdir}/zfs-\${pkgver/_/-}"` which converts underscores to hyphens, producing the correct path `zfs-2.4.0-rc3`.

**Key Insight**: The pkgver in PKGBUILD uses underscores (`2.4.0_rc3`) to comply with pacman version naming, but the source tarball uses hyphens (`2.4.0-rc3`). The workdir pattern must handle this transformation correctly.

### 2. initcpio Hook Path Issue

**Problem**: mkinitcpio errors about missing files in `/lib/udev/`

**Root Cause**: The archzfs initcpio hook was written for older Arch Linux where `/lib` existed as a separate directory. Modern Arch has merged `/lib` into `/usr/lib`.

**Solution Applied**: ✅ **Permanently Fixed** - Updated the source template `src/zfs-utils/zfs-utils.initcpio.install` to use `/usr/lib/` paths instead of `/lib/`.

**Result**: All packages built from this repository now automatically include the correct paths. No manual post-installation fixes are required.

**Hash Updated**: The `zfs_initcpio_install_hash` in `conf.sh` has been updated to:
```bash
zfs_initcpio_install_hash="1e8c13ced9dc9696565cd232fcf8d8b6ecbe45dcb594bef13b4a9bfeb0ce02b6"
```

### 3. Package Dependency During Build

**Problem**: Building zfs-dkms-rc failed because it depends on `zfs-utils-rc=2.4.0_rc3`, which wasn't installed yet.

**Solution**: Use `makepkg -s --nodeps` to skip dependency checking during the build phase. The dependency information is still correctly encoded in the package; it's just not enforced during building.

**Why This Works**: The dependency is a runtime dependency, not a build dependency. DKMS packages don't actually need zfs-utils to compile; they just need it to function.

### 4. Build System Architecture

**Discovery**: The archzfs build system is template-driven:
- Source templates: `src/zfs-*/PKGBUILD.sh`
- Configuration: `src/kernels/*.sh` and `conf.sh`
- Generated output: `packages/*/PKGBUILD`

**Key Takeaway**: Never edit generated PKGBUILDs directly. Always modify:
1. Configuration variables in `conf.sh`
2. Template functions in `src/kernels/*.sh`
3. Template files in `src/zfs-*/PKGBUILD.sh`

Then regenerate with `./build.sh <mode> update`.

### 5. Version String Transformations

**Understanding the pattern**:
```bash
# GitHub Release Tag:    zfs-2.4.0-rc3
# conf.sh variable:       openzfs_rc_version="2.4.0-rc3"
# PKGBUILD pkgver:        2.4.0_rc3  (hyphens → underscores)
# Source tarball name:    zfs-2.4.0-rc3.tar.gz
# Extracted directory:    zfs-2.4.0-rc3/
# Package name:           zfs-dkms-rc-2.4.0_rc3-1-x86_64.pkg.tar.zst
```

**Transformation used**: `${openzfs_rc_version/-/_}` converts hyphens to underscores for pkgver.

---

## Helper Script for Future Builds

### Usage of `build-openzfs-version.sh`

Created [build-openzfs-version.sh](build-openzfs-version.sh) to automate building any OpenZFS version:

```bash
# Build any RC version
sudo ./build-openzfs-version.sh 2.4.0-rc4 rc

# Build any stable version
sudo ./build-openzfs-version.sh 2.3.5 stable

# Build the current version again
sudo ./build-openzfs-version.sh 2.4.0-rc3 rc
```

**What the script does**:
1. Downloads the tarball from GitHub
2. Computes SHA256 hash
3. Updates `conf.sh` with new version and hash
4. Regenerates PKGBUILDs
5. Shows verification and next steps

**Note**: The script generates PKGBUILDs but doesn't build packages (since that requires ccm or manual makepkg).

---

## Building Other Versions

### To build a different OpenZFS version:

**Option 1: Use the helper script**
```bash
sudo ./build-openzfs-version.sh <version> <type>
# Then build manually with makepkg as shown above
```

**Option 2: Manual process**

1. **Get the version hash**:
   ```bash
   VERSION="2.4.0-rc4"  # or any version
   wget "https://github.com/openzfs/zfs/releases/download/zfs-${VERSION}/zfs-${VERSION}.tar.gz"
   sha256sum "zfs-${VERSION}.tar.gz"
   ```

2. **Update `conf.sh`**:
   ```bash
   # For RC versions:
   openzfs_rc_version="2.4.0-rc4"
   zfs_rc_src_hash="<hash_from_above>"

   # For stable versions:
   openzfs_version="2.3.5"
   zfs_src_hash="<hash_from_above>"
   ```

3. **Regenerate PKGBUILDs**:
   ```bash
   sudo ./build.sh utils update
   sudo ./build.sh dkms update
   ```

4. **Build packages**:
   ```bash
   cd packages/_utils/zfs-utils-rc  # or zfs-utils for stable
   makepkg -s --noconfirm

   cd ../../dkms/zfs-dkms-rc  # or zfs-dkms for stable
   makepkg -s --nodeps --noconfirm
   ```

---

## Troubleshooting

### Build fails with "directory not found"

**Symptom**: Error message like:
```
cd: /path/to/src/zfs-2.4.0: No such file or directory
```

**Cause**: Incorrect workdir pattern in kernel config files.

**Solution**: Verify workdir in `src/kernels/_utils.sh` and `src/kernels/dkms.sh` uses:
```bash
zfs_workdir="\${srcdir}/zfs-\${pkgver/_/-}"  # For RC versions
```

### mkinitcpio errors about missing files

**Symptom**: Errors like:
```
ERROR: file not found: '/lib/udev/vdev_id'
```

**Status**: ✅ **Fixed in current build** - This issue has been permanently resolved in the source templates as of November 2025.

**If you encounter this**: You're using an old package built before the fix. Solutions:
1. **Recommended**: Rebuild packages using the current repository (paths are now correct)
2. **Temporary workaround** (if you can't rebuild): Manually fix the installed hook:
```bash
sudo sed -i 's|/lib/udev/|/usr/lib/udev/|g' /usr/lib/initcpio/install/zfs
sudo sed -i 's|/lib/libgcc_s.so.1|/usr/lib/libgcc_s.so.1|g' /usr/lib/initcpio/install/zfs
sudo mkinitcpio -P
```

### Hash mismatch error during build

**Symptom**: makepkg reports SHA256 hash doesn't match

**Solution**:
1. Redownload the tarball and recompute hash
2. Verify you're using the correct version string
3. Update conf.sh with correct hash
4. Regenerate PKGBUILDs with `./build.sh <mode> update`

### Package dependency conflicts

**Symptom**: pacman reports conflicts with existing zfs packages

**Solution**:
```bash
# Remove old packages first
sudo pacman -R zfs-dkms zfs-utils

# Or force replace
sudo pacman -U --overwrite='*' <packages>
```

### DKMS module not building automatically

**Symptom**: `dkms status` shows module added but not built

**Solution**:
```bash
# Manually trigger DKMS build
sudo dkms install zfs/2.4.0_rc3 -k $(uname -r)

# Or rebuild initramfs (triggers DKMS)
sudo mkinitcpio -P
```

---

## File Reference

### Key Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `conf.sh` | Version and hash configuration | [conf.sh](conf.sh) |
| `src/kernels/dkms.sh` | DKMS build configuration | [src/kernels/dkms.sh](src/kernels/dkms.sh) |
| `src/kernels/_utils.sh` | Utils build configuration | [src/kernels/_utils.sh](src/kernels/_utils.sh) |
| `build-openzfs-version.sh` | Helper script for any version | [build-openzfs-version.sh](build-openzfs-version.sh) |

### Generated Files (after update)

| File | Purpose |
|------|---------|
| `packages/_utils/zfs-utils-rc/PKGBUILD` | Utils package build instructions |
| `packages/dkms/zfs-dkms-rc/PKGBUILD` | DKMS package build instructions |

### Built Packages (after make)

| File | Size | Description |
|------|------|-------------|
| `packages/_utils/zfs-utils-rc/zfs-utils-rc-2.4.0_rc3-1-x86_64.pkg.tar.zst` | 31 MB | ZFS userspace utilities |
| `packages/dkms/zfs-dkms-rc/zfs-dkms-rc-2.4.0_rc3-1-x86_64.pkg.tar.zst` | 33 MB | DKMS kernel module source |

---

## Quick Reference Commands

### Check Installation Status
```bash
# ZFS version
zfs --version

# Installed packages
pacman -Q | grep zfs

# DKMS status
dkms status

# Kernel module info
modinfo zfs | head -10

# Check if module is loaded
lsmod | grep zfs
```

### Reinstall Packages
```bash
# From your archzfs repository directory
sudo pacman -U \
  packages/_utils/zfs-utils-rc/zfs-utils-rc-*-x86_64.pkg.tar.zst \
  packages/dkms/zfs-dkms-rc/zfs-dkms-rc-*-x86_64.pkg.tar.zst
```

### Rebuild for New Kernel
```bash
# DKMS handles this automatically, but to force:
sudo dkms install zfs/2.4.0_rc3 -k $(uname -r)
```

---

## Architecture Overview

### Build System Flow

```
conf.sh (version config)
         ↓
build.sh <mode> update
         ↓
src/kernels/<mode>.sh (calls update functions)
         ↓
src/zfs-*/PKGBUILD.sh (templates)
         ↓
packages/<mode>/<pkg>/PKGBUILD (generated)
         ↓
makepkg -s
         ↓
*.pkg.tar.zst (installable package)
```

### Package Dependencies

```
zfs-utils-rc
    ↓ (provides zfs-utils)
zfs-dkms-rc (depends on zfs-utils-rc)
    ↓ (installs DKMS source)
DKMS system
    ↓ (compiles on install/kernel update)
zfs.ko (kernel module)
```

---

## Important Notes

### Version Naming Convention

- **GitHub tag**: `zfs-2.4.0-rc3` (hyphen before rc)
- **Package version**: `2.4.0_rc3` (underscore before rc)
- **DKMS version**: `2.4.0_rc3` (underscore before rc)

Always use hyphens in `conf.sh` (matching GitHub), the build system converts to underscores for package naming.

### When to Use RC vs Stable

**Use RC packages when**:
- You need bleeding-edge features
- You have kernel compatibility issues with stable
- You're testing before a stable release
- You contribute to OpenZFS development

**Use Stable packages when**:
- You need production stability
- You don't need the latest features
- The stable version works with your kernel

### Kernel Compatibility

DKMS packages automatically rebuild when you:
- Upgrade your kernel
- Manually trigger with `sudo dkms install zfs/<version>`

Check compatibility at: https://github.com/openzfs/zfs/issues

---

## Additional Resources

### Official Documentation
- OpenZFS: https://openzfs.org/
- archzfs GitHub: https://github.com/archzfs/archzfs
- Arch Wiki ZFS: https://wiki.archlinux.org/title/ZFS

### Release Information
- OpenZFS Releases: https://github.com/openzfs/zfs/releases
- OpenZFS 2.4.0-rc3: https://github.com/openzfs/zfs/releases/tag/zfs-2.4.0-rc3

### Build System
- PKGBUILD Documentation: https://wiki.archlinux.org/title/PKGBUILD
- DKMS: https://wiki.archlinux.org/title/Dynamic_Kernel_Module_Support
- makepkg: https://wiki.archlinux.org/title/Makepkg

---

## Version History & Changes

### Critical Fixes Included
- **RC Build Support**: Enabled and fixed RC (release candidate) package builds
- **Workdir Path Fix**: Corrected `zfs_workdir` pattern from `/_rc*/` to `/_/-/` in RC configs
- **initcpio Hook Fix**: ✅ **Permanently Fixed** - Updated source template `src/zfs-utils/zfs-utils.initcpio.install` to use `/usr/lib/` paths instead of `/lib/` (no manual post-install fixes needed)
- **Updated Hash**: Updated `zfs_initcpio_install_hash` in `conf.sh` to match the fixed template
- **Helper Script**: Added `build-openzfs-version.sh` for building any OpenZFS version
- **Build Guide**: Complete documentation with troubleshooting steps

---

## Contributors

- **Original archzfs**: Jan Houben, Jesus Alvarez
- **Documentation**: Comprehensive guide with critical RC build fixes

---

## License

This documentation follows the same license as archzfs (CDDL).

---

## Contact & Support

For issues specific to this build:
- Check this documentation first
- Review the Troubleshooting section
- Check archzfs issues: https://github.com/archzfs/archzfs/issues

For OpenZFS issues:
- OpenZFS issue tracker: https://github.com/openzfs/zfs/issues

---

# Appendix A: Quick Start Guide

For users who just want to build and install quickly without reading the full documentation.

## Prerequisites

```bash
sudo pacman -S base-devel python python-setuptools python-cffi dkms
```

## Easiest Method: Use Makefile

```bash
# Build RC packages (they'll be copied to root directory)
sudo make rc

# Or build stable packages
sudo make stable

# Install RC packages (with confirmation prompt)
make install-rc

# Or install stable packages
make install-stable

# Verify installation
make verify
```

See `make help` for all available commands.

## Alternative: Helper Script + Manual Build

Use the helper script to configure, then build manually:

```bash
# For RC versions
sudo ./build-openzfs-version.sh 2.4.0-rc3 rc

# For stable versions
sudo ./build-openzfs-version.sh 2.3.5 stable
```

Then build the packages:

```bash
# Build utils
cd packages/_utils/zfs-utils-rc  # or zfs-utils for stable
makepkg -s --noconfirm

# Build DKMS
cd ../../dkms/zfs-dkms-rc  # or zfs-dkms for stable
makepkg -s --nodeps --noconfirm
```

## Installation Methods

### Using Makefile (Recommended)

```bash
# Install RC packages (will prompt for confirmation)
make install-rc

# Or install stable packages
make install-stable
```

### Manual Installation

```bash
# Install from root directory (if using Makefile to build)
sudo pacman -U zfs-utils-rc-*.pkg.tar.zst zfs-dkms-rc-*.pkg.tar.zst

# Or install from packages subdirectories
sudo pacman -U \
  packages/_utils/zfs-utils-rc/*.pkg.tar.zst \
  packages/dkms/zfs-dkms-rc/*.pkg.tar.zst
```

## Post-Installation: Enable ZFS Services

**Important**: To have your ZFS pools auto-import at boot:

```bash
sudo systemctl enable zfs.target
sudo systemctl enable zfs-import-cache.service
sudo systemctl enable zfs-import.target
sudo systemctl enable zfs-mount.service
```

Or simply:
```bash
sudo systemctl enable zfs.target
```

## Verification

```bash
zfs --version
dkms status | grep zfs
pacman -Q | grep zfs
```

---

# Appendix B: Build Safety and System Cleanliness

This section explains what the build process touches on your system and how to ensure clean, isolated builds.

## TL;DR - Build Safety

```bash
# Build process (NO system changes)
sudo make rc             # Builds in packages/ subdirs only

# Verify build is clean
make check-build         # Confirms no system pollution

# See what would be installed (before installing)
make list-files          # Preview package contents

# Install packages (DOES modify system)
make install-rc          # Installs to /usr/, /etc/, /lib/

# Verify what's on system
make show-installed      # See all installed files

# Complete removal
make uninstall-all       # Removes everything
make verify-clean        # Confirms system is clean
```

## Build Process: What Touches Your System

### ✅ Build Phase (NO System Changes)

When you run `sudo make rc` or `make stable`:

**What happens IN the repository:**
```
archzfs/
├── packages/_utils/zfs-utils-rc/
│   ├── src/                    # Downloaded source code
│   ├── pkg/                    # Staged files for package
│   └── *.pkg.tar.zst          # Final package
├── packages/dkms/zfs-dkms-rc/
│   ├── src/                    # Downloaded source code
│   ├── pkg/                    # Staged files for package
│   └── *.pkg.tar.zst          # Final package
└── *.pkg.tar.zst              # Copied to root for convenience
```

**System directories touched:** NONE

**Why sudo is needed:** Only to run `./build.sh` for PKGBUILD generation. The actual `makepkg` build doesn't modify system files.

### ❌ Installation Phase (DOES Modify System)

When you run `make install-rc`:

**System directories modified:**
```
/usr/bin/           - ZFS command-line tools
/usr/lib/           - Libraries and kernel module source
/usr/lib/systemd/   - Service files
/usr/lib/udev/      - Device management
/etc/zfs/           - Configuration files
/etc/systemd/       - System service links
/var/lib/dkms/      - DKMS module source
/lib/modules/       - Compiled kernel modules
```

**Pacman database:** Updated to track all 7000+ installed files

## Verification Commands

### Before Installation

```bash
# Check build process is clean
make check-build

# Preview what would be installed
make list-files

# Show packages in root directory
make info
```

**Expected:** All artifacts in `packages/` subdirectories, no system changes.

### After Installation

```bash
# Verify ZFS installation
make verify

# See all installed files
make show-installed

# Check file counts
pacman -Ql zfs-utils-rc | wc -l   # ~3000 files
pacman -Ql zfs-dkms-rc | wc -l    # ~4000 files
```

**Expected:** All files tracked by pacman, no orphaned files.

### After Uninstallation

```bash
# Remove all ZFS
make uninstall-all

# Verify completely clean
make verify-clean
```

**Expected:** No ZFS packages, no kernel module, no stray files.

## What Gets Installed

### zfs-utils-rc Package (~3000 files)

**Binaries** (`/usr/bin/`):
- `zfs`, `zpool`, `zdb` - Main ZFS commands
- `mount.zfs`, `fsck.zfs` - Filesystem integration
- `zed`, `zgenhostid` - Daemon and utilities

**Libraries** (`/usr/lib/`):
- `libnvpair.so`, `libuutil.so`, `libzfs.so` - Core libraries
- `zfs/` - Module helpers
- `python3.*/site-packages/` - Python bindings

**Configuration** (`/etc/`):
- `zfs/` - ZFS configuration
- `systemd/system/` - Service files
- `modules-load.d/zfs.conf` - Auto-load module

**Initramfs** (`/usr/lib/initcpio/`):
- `install/zfs` - Early boot hook
- `hooks/zfs` - Hook implementation

### zfs-dkms-rc Package (~4000+ files)

**DKMS Source** (`/usr/src/zfs-2.4.0_rc3/`):
- All OpenZFS source code
- Build configuration
- `dkms.conf` - DKMS build instructions

**Compiled Modules** (after DKMS builds):
- `/lib/modules/<kernel>/extra/zfs.ko` - Main module
- `/lib/modules/<kernel>/extra/*.ko` - Helper modules
- Built automatically when kernel updates

## Ensuring Clean Builds

### Option 1: Non-Root Build (Safest)

```bash
# Generate PKGBUILDs (requires sudo)
sudo make update-rc

# Build as regular user (no system changes)
cd packages/_utils/zfs-utils-rc
makepkg -s

cd ../../dkms/zfs-dkms-rc
makepkg -s --nodeps

# Packages are created, system untouched
make check-build
```

### Option 2: Makefile Build (Convenient)

```bash
# Build (uses sudo only for PKGBUILD generation)
sudo make rc

# Verify no pollution
make check-build
```

### Option 3: Clean Chroot (Gold Standard)

The archzfs project was designed to use `clean-chroot-manager`:

```bash
# Install clean-chroot-manager
yay -S clean-chroot-manager

# Use original build.sh with chroot
sudo ./build.sh utils make -u
sudo ./build.sh dkms make -u
```

**Benefits:**
- Completely isolated build environment
- No chance of system pollution
- Catches missing dependencies
- Matches official package building

**Note:** Our Makefile doesn't use chroot (for simplicity), but you can use the original `build.sh` if you install `ccm`.

## Common Safety Questions

### Q: Does `sudo make rc` modify my system?

**A:** No. It only:
1. Runs `./build.sh` to generate PKGBUILDs (in repo)
2. Runs `makepkg` to build packages (in `packages/`)
3. Copies `.pkg.tar.zst` files to root directory

Your system files are unchanged.

### Q: How do I verify no system pollution?

**A:** Run after building:
```bash
make check-build
```

This confirms all artifacts are in the repository.

### Q: Do I need the `zfs` hook in `/etc/mkinitcpio.conf`?

**A:** Only if your root filesystem is on ZFS.

**If your root is on BTRFS/ext4/other:** Do NOT add `zfs` to HOOKS. ZFS modules will load automatically when you use ZFS pools for data storage.

**If your root is on ZFS:** You need the `zfs` hook in early boot hooks AND the initcpio template fixes in this repository.

### Q: How do ZFS pools auto-import at boot?

**A:** Enable the systemd services after installation:
```bash
sudo systemctl enable zfs.target
```

This enables:
- `zfs-import-cache.service` - Imports pools from cache
- `zfs-import.target` - Scans for pools
- `zfs-mount.service` - Mounts datasets

ZFS datasets do NOT go in `/etc/fstab`. They have built-in mountpoint properties.

### Q: What if I want to share packages with other machines?

**A:** Perfect! The packages in root directory are self-contained:
```bash
# On build machine
sudo make rc
scp *.pkg.tar.zst other-machine:

# On other machine
sudo pacman -U zfs-*.pkg.tar.zst
```

No source code or build artifacts needed on other machines.

### Q: How do I completely remove ZFS?

**A:**
```bash
# Interactive removal
make uninstall-all

# Verify clean
make verify-clean
```

This removes packages, kernel modules, and verifies no stray files.

## Rollback Instructions

### If Something Goes Wrong

**Uninstall packages:**
```bash
make uninstall-all
make verify-clean
```

**Remove DKMS modules manually (if needed):**
```bash
sudo dkms remove zfs/2.4.0_rc3 --all
sudo rm -rf /var/lib/dkms/zfs
```

**Unload kernel module:**
```bash
sudo modprobe -r zfs
```

**Clean build artifacts:**
```bash
make clean-all
rm -rf packages/_utils/*/src packages/_utils/*/pkg
rm -rf packages/dkms/*/src packages/dkms/*/pkg
```

**Reinstall stable ZFS from AUR:**
```bash
yay -S zfs-dkms zfs-utils
```

## Summary Table

| Phase | System Modified? | Reversible? | Command |
|-------|------------------|-------------|---------|
| Build | ❌ No | N/A | `make rc` |
| Install | ✅ Yes | Yes (pacman -R) | `make install-rc` |
| Uninstall | ✅ Yes | Yes (reinstall) | `make uninstall-all` |

**Key Point:** Building is safe and isolated. Installing modifies system but is fully tracked by pacman and completely reversible.

Use `make check-build` to verify build cleanliness.
Use `make show-installed` to see what's on your system.
Use `make verify-clean` after removal to confirm cleanup.

---

# Appendix C: Using the Pacman Repository

This repository provides automated builds via GitHub Actions, creating a pacman repository you can add to your system.

## Two Repositories Available

### Stable Repository

For production use with tested, stable OpenZFS releases:

```ini
# Add to /etc/pacman.conf
[archzfs]
SigLevel = Optional TrustAll
Server = https://github.com/YOUR_USERNAME/archzfs/releases/download/latest
```

Then install:
```bash
sudo pacman -Sy archzfs/zfs-dkms archzfs/zfs-utils
sudo systemctl enable zfs.target
```

### RC Repository

For testing or kernel compatibility with release candidates:

```ini
# Add to /etc/pacman.conf
[archzfs-rc]
SigLevel = Optional TrustAll
Server = https://github.com/YOUR_USERNAME/archzfs/releases/download/rc-latest
```

Then install:
```bash
sudo pacman -Sy archzfs-rc/zfs-dkms-rc archzfs-rc/zfs-utils-rc
sudo systemctl enable zfs.target
```

## GitHub Actions Workflows

Two automated workflows build and publish packages:

### Stable Builds (`build-stable.yml`)

**Triggered by:**
- Tags: `v2.3.5`, `v2.4.0`, etc.
- Manual: GitHub Actions → Build Stable Packages → Run workflow

**Creates release:**
- Tag: `latest`
- Repository database: `archzfs.db.tar.gz`
- Packages: `zfs-utils-*.pkg.tar.zst`, `zfs-dkms-*.pkg.tar.zst`

**To trigger:**
```bash
# Create and push a version tag
git tag v2.3.5
git push origin v2.3.5

# Or use GitHub Actions web UI for manual trigger
```

### RC Builds (`build-rc.yml`)

**Triggered by:**
- Tags: `rc-2.4.0-rc3`, `rc-2.4.0-rc4`, etc.
- Manual: GitHub Actions → Build RC Packages → Run workflow

**Creates release:**
- Tag: `rc-latest`
- Repository database: `archzfs-rc.db.tar.gz`
- Packages: `zfs-utils-rc-*.pkg.tar.zst`, `zfs-dkms-rc-*.pkg.tar.zst`

**To trigger:**
```bash
# Create and push an RC tag
git tag rc-2.4.0-rc3
git push origin rc-2.4.0-rc3

# Or use GitHub Actions web UI for manual trigger
```

## How It Works

1. **Tag Push**: You push a version tag to trigger the workflow
2. **Build**: GitHub Actions runs in Arch Linux container
3. **Configure**: Uses `build-openzfs-version.sh` to configure the build
4. **Compile**: Builds utils and DKMS packages
5. **Repository**: Creates pacman database with `repo-add`
6. **Release**: Updates the appropriate release (`latest` or `rc-latest`)
7. **Install**: Users can install via pacman from the release URL

## Workflow Features

- ✅ Builds in clean Arch Linux container
- ✅ Uses non-root user for `makepkg`
- ✅ Excludes debug packages
- ✅ Creates proper pacman repository database
- ✅ Generates detailed release notes
- ✅ Updates release atomically (always points to latest build)
- ✅ Manual workflow dispatch option

## Setting Up Automated Builds

### Initial Setup

1. **Fork the repository** to your GitHub account

2. **Enable GitHub Actions** (should be enabled by default)

3. **Push tags to trigger builds:**

   For RC builds:
   ```bash
   git tag rc-2.4.0-rc3
   git push origin rc-2.4.0-rc3
   ```

   For stable builds:
   ```bash
   git tag v2.3.5
   git push origin v2.3.5
   ```

4. **GitHub Actions will:**
   - Build packages
   - Create/update the release
   - Upload packages and repository database

5. **Users can now install** from your repository URL

### Updating to New Versions

When a new OpenZFS version is released:

```bash
# Update your fork
git pull upstream master

# Create a tag for the new version
git tag rc-2.4.0-rc4    # For RC
# OR
git tag v2.4.0          # For stable

# Push the tag
git push origin rc-2.4.0-rc4
# OR
git push origin v2.4.0

# GitHub Actions builds automatically
# The 'latest' or 'rc-latest' release is updated
# Users get the new version on next 'pacman -Sy'
```

### Manual Builds

You can also trigger builds manually from GitHub Actions web UI:

1. Go to: **Actions** → **Build RC Packages** (or **Build Stable Packages**)
2. Click: **Run workflow**
3. Enter: OpenZFS version (e.g., `2.4.0-rc3`)
4. Click: **Run workflow**

## Repository URLs

Replace `YOUR_USERNAME` with your GitHub username:

**Stable:**
```
https://github.com/YOUR_USERNAME/archzfs/releases/download/latest
```

**RC:**
```
https://github.com/YOUR_USERNAME/archzfs/releases/download/rc-latest
```

## Advantages

**For maintainers:**
- Automated building on new releases
- No need to manually build and upload
- Consistent build environment
- Version history in tags

**For users:**
- Simple pacman integration
- Always get latest version with `pacman -Sy`
- No manual building required
- Can choose stable or RC repository

## Example User Workflow

```bash
# Add repository
sudo tee -a /etc/pacman.conf <<EOF

[archzfs]
SigLevel = Optional TrustAll
Server = https://github.com/YOUR_USERNAME/archzfs/releases/download/latest
EOF

# Install packages
sudo pacman -Sy archzfs/zfs-dkms archzfs/zfs-utils

# Enable services
sudo systemctl enable zfs.target

# Check version
zfs --version

# Update when new versions are released
sudo pacman -Sy && sudo pacman -S archzfs/zfs-dkms archzfs/zfs-utils
```

## Notes

**Signature verification:**
- `SigLevel = Optional TrustAll` disables signature checking
- For production use, consider setting up GPG signatures
- See: https://wiki.archlinux.org/title/Pacman/Package_signing

**Release persistence:**
- The `latest` and `rc-latest` tags are updated in place
- Each new build overwrites the previous release
- Users always get the newest version
- For historical versions, use specific version tags

**Multiple architectures:**
- Current workflows build for x86_64 only
- For ARM support, extend workflows with ARM runners