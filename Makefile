# Makefile for building OpenZFS packages for Arch Linux
# Usage:
#   make rc          - Build RC packages
#   make stable      - Build stable packages
#   make install-rc  - Install RC packages
#   make install-stable - Install stable packages
#   make clean       - Clean built packages
#   make verify      - Verify installation

.PHONY: help rc stable install-rc install-stable clean verify clean-all update-rc update-stable

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Package paths
RC_UTILS_DIR := packages/_utils/zfs-utils-rc
RC_DKMS_DIR := packages/dkms/zfs-dkms-rc
STABLE_UTILS_DIR := packages/_utils/zfs-utils
STABLE_DKMS_DIR := packages/dkms/zfs-dkms

# Package files in root
RC_UTILS_PKG := $(wildcard zfs-utils-rc-*-x86_64.pkg.tar.zst)
RC_DKMS_PKG := $(wildcard zfs-dkms-rc-*-x86_64.pkg.tar.zst)
STABLE_UTILS_PKG := $(wildcard zfs-utils-*-x86_64.pkg.tar.zst)
STABLE_DKMS_PKG := $(wildcard zfs-dkms-*-x86_64.pkg.tar.zst)

help:
	@echo "$(BLUE)OpenZFS Package Builder for Arch Linux$(NC)"
	@echo ""
	@echo "$(GREEN)Build Commands:$(NC)"
	@echo "  make rc              - Build RC packages and copy to root"
	@echo "  make stable          - Build stable packages and copy to root"
	@echo "  make update-rc       - Update RC PKGBUILDs only (no build)"
	@echo "  make update-stable   - Update stable PKGBUILDs only (no build)"
	@echo ""
	@echo "$(GREEN)Installation Commands:$(NC)"
	@echo "  make install-rc      - Install RC packages from root"
	@echo "  make install-stable  - Install stable packages from root"
	@echo "  make fix-initcpio    - Fix initcpio hook paths (run once)"
	@echo ""
	@echo "$(GREEN)Verification Commands:$(NC)"
	@echo "  make verify          - Verify ZFS installation"
	@echo "  make check-build     - Verify build process is clean (no system pollution)"
	@echo "  make list-files      - List files in packages (before install)"
	@echo "  make show-installed  - Show all installed ZFS files on system"
	@echo "  make verify-clean    - Verify system is clean after uninstall"
	@echo ""
	@echo "$(GREEN)Cleanup Commands:$(NC)"
	@echo "  make clean           - Remove packages from root"
	@echo "  make clean-all       - Remove all built packages (root + packages/)"
	@echo "  make uninstall-all   - Remove ALL ZFS from system (with confirmation)"
	@echo ""
	@echo "$(GREEN)Information:$(NC)"
	@echo "  make info            - Show configuration and package status"
	@echo ""
	@echo "$(YELLOW)Current Configuration:$(NC)"
	@echo "  Stable: $$(grep '^openzfs_version=' conf.sh | cut -d'"' -f2)"
	@echo "  RC:     $$(grep '^openzfs_rc_version=' conf.sh | cut -d'"' -f2)"

# Build RC packages
rc: update-rc
	@echo "$(BLUE)Building RC packages...$(NC)"
	@echo "$(YELLOW)Building zfs-utils-rc...$(NC)"
	cd $(RC_UTILS_DIR) && makepkg -sf --noconfirm
	@echo "$(YELLOW)Building zfs-dkms-rc...$(NC)"
	cd $(RC_DKMS_DIR) && makepkg -sf --nodeps --noconfirm
	@echo "$(GREEN)Copying packages to root...$(NC)"
	@for pkg in $(RC_UTILS_DIR)/zfs-utils-rc-*-x86_64.pkg.tar.zst; do \
		[ -f "$$pkg" ] && echo "$$pkg" | grep -v debug && cp -v "$$pkg" . || true; \
	done
	@cp -v $(RC_DKMS_DIR)/zfs-dkms-rc-*-x86_64.pkg.tar.zst . 2>/dev/null || true
	@echo "$(GREEN)✓ RC packages built and ready in root directory$(NC)"
	@ls -lh zfs-*-rc-*.pkg.tar.zst 2>/dev/null | grep -v debug || true

# Build stable packages
stable: update-stable
	@echo "$(BLUE)Building stable packages...$(NC)"
	@echo "$(YELLOW)Building zfs-utils...$(NC)"
	cd $(STABLE_UTILS_DIR) && makepkg -sf --noconfirm
	@echo "$(YELLOW)Building zfs-dkms...$(NC)"
	cd $(STABLE_DKMS_DIR) && makepkg -sf --nodeps --noconfirm
	@echo "$(GREEN)Copying packages to root...$(NC)"
	@for pkg in $(STABLE_UTILS_DIR)/zfs-utils-*-x86_64.pkg.tar.zst; do \
		[ -f "$$pkg" ] && echo "$$pkg" | grep -v debug && cp -v "$$pkg" . || true; \
	done
	@cp -v $(STABLE_DKMS_DIR)/zfs-dkms-*-x86_64.pkg.tar.zst . 2>/dev/null || true
	@echo "$(GREEN)✓ Stable packages built and ready in root directory$(NC)"
	@ls -lh zfs-utils-*.pkg.tar.zst zfs-dkms-*.pkg.tar.zst 2>/dev/null | grep -v '\-rc\-' | grep -v debug || true

# Update PKGBUILDs only
update-rc:
	@echo "$(BLUE)Updating RC PKGBUILDs...$(NC)"
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(RED)Error: PKGBUILD generation requires root (uses build.sh)$(NC)"; \
		echo "$(YELLOW)Run: sudo make rc$(NC)"; \
		exit 1; \
	fi
	./build.sh utils update
	./build.sh dkms update
	@echo "$(GREEN)✓ RC PKGBUILDs updated$(NC)"

update-stable:
	@echo "$(BLUE)Updating stable PKGBUILDs...$(NC)"
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "$(RED)Error: PKGBUILD generation requires root (uses build.sh)$(NC)"; \
		echo "$(YELLOW)Run: sudo make stable$(NC)"; \
		exit 1; \
	fi
	./build.sh utils update
	./build.sh dkms update
	@echo "$(GREEN)✓ Stable PKGBUILDs updated$(NC)"

# Install RC packages
install-rc:
	@echo "$(BLUE)Installing RC packages...$(NC)"
	@if [ -z "$(RC_UTILS_PKG)" ] || [ -z "$(RC_DKMS_PKG)" ]; then \
		echo "$(RED)Error: RC packages not found in root directory$(NC)"; \
		echo "$(YELLOW)Run 'make rc' first to build them$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)This will remove existing zfs packages and install RC versions$(NC)"
	@echo "Packages to install:"
	@ls -lh $(RC_UTILS_PKG) $(RC_DKMS_PKG)
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		sudo pacman -R --noconfirm zfs-dkms zfs-utils 2>/dev/null || true; \
		sudo pacman -U --noconfirm $(RC_UTILS_PKG) $(RC_DKMS_PKG); \
		echo "$(GREEN)✓ RC packages installed$(NC)"; \
	else \
		echo "$(YELLOW)Installation cancelled$(NC)"; \
	fi

# Install stable packages
install-stable:
	@echo "$(BLUE)Installing stable packages...$(NC)"
	@if [ -z "$(STABLE_UTILS_PKG)" ] || [ -z "$(STABLE_DKMS_PKG)" ]; then \
		echo "$(RED)Error: Stable packages not found in root directory$(NC)"; \
		echo "$(YELLOW)Run 'make stable' first to build them$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)This will remove existing zfs packages and install stable versions$(NC)"
	@echo "Packages to install:"
	@ls -lh $(STABLE_UTILS_PKG) $(STABLE_DKMS_PKG)
	@echo ""
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		sudo pacman -R --noconfirm zfs-dkms zfs-utils 2>/dev/null || true; \
		sudo pacman -U --noconfirm $(STABLE_UTILS_PKG) $(STABLE_DKMS_PKG); \
		echo "$(GREEN)✓ Stable packages installed$(NC)"; \
	else \
		echo "$(YELLOW)Installation cancelled$(NC)"; \
	fi

# Fix initcpio hook paths (one-time)
fix-initcpio:
	@echo "$(BLUE)Fixing initcpio hook paths...$(NC)"
	@if [ ! -f /usr/lib/initcpio/install/zfs ]; then \
		echo "$(RED)Error: ZFS not installed or initcpio hook not found$(NC)"; \
		exit 1; \
	fi
	sudo sed -i 's|/lib/udev/|/usr/lib/udev/|g' /usr/lib/initcpio/install/zfs
	sudo sed -i 's|/lib/libgcc_s.so.1|/usr/lib/libgcc_s.so.1|g' /usr/lib/initcpio/install/zfs
	@echo "$(YELLOW)Rebuilding initramfs...$(NC)"
	sudo mkinitcpio -P
	@echo "$(GREEN)✓ Initcpio hook fixed and initramfs rebuilt$(NC)"

# Clean packages from root
clean:
	@echo "$(BLUE)Cleaning packages from root directory...$(NC)"
	rm -fv zfs-utils-*.pkg.tar.zst zfs-dkms-*.pkg.tar.zst
	@echo "$(GREEN)✓ Root directory cleaned$(NC)"

# Clean all built packages
clean-all: clean
	@echo "$(BLUE)Cleaning all built packages...$(NC)"
	rm -fv $(RC_UTILS_DIR)/*.pkg.tar.zst
	rm -fv $(RC_DKMS_DIR)/*.pkg.tar.zst
	rm -fv $(STABLE_UTILS_DIR)/*.pkg.tar.zst
	rm -fv $(STABLE_DKMS_DIR)/*.pkg.tar.zst
	@echo "$(GREEN)✓ All packages cleaned$(NC)"

# Verify installation
verify:
	@echo "$(BLUE)Verifying ZFS installation...$(NC)"
	@echo ""
	@echo "$(YELLOW)ZFS Version:$(NC)"
	@zfs --version || echo "$(RED)ZFS not installed$(NC)"
	@echo ""
	@echo "$(YELLOW)Installed Packages:$(NC)"
	@pacman -Q | grep zfs || echo "$(RED)No ZFS packages found$(NC)"
	@echo ""
	@echo "$(YELLOW)DKMS Status:$(NC)"
	@dkms status | grep zfs || echo "$(RED)No ZFS DKMS modules$(NC)"
	@echo ""
	@echo "$(YELLOW)Kernel Module:$(NC)"
	@modinfo zfs | head -5 || echo "$(RED)ZFS module not found$(NC)"
	@echo ""
	@echo "$(YELLOW)Module Loaded:$(NC)"
	@lsmod | grep -E "^zfs " && echo "$(GREEN)✓ ZFS module loaded$(NC)" || echo "$(YELLOW)⚠ ZFS module not loaded$(NC)"

# Version information
info:
	@echo "$(BLUE)Configuration Information$(NC)"
	@echo ""
	@echo "$(YELLOW)Versions in conf.sh:$(NC)"
	@echo "  Stable: $$(grep '^openzfs_version=' conf.sh | cut -d'"' -f2)"
	@echo "  RC:     $$(grep '^openzfs_rc_version=' conf.sh | cut -d'"' -f2)"
	@echo ""
	@echo "$(YELLOW)Built packages in root:$(NC)"
	@ls -lh *.pkg.tar.zst 2>/dev/null | awk '{print "  " $$9 " (" $$5 ")"}' || echo "  None"
	@echo ""
	@echo "$(YELLOW)Package locations:$(NC)"
	@echo "  RC Utils:   $(RC_UTILS_DIR)"
	@echo "  RC DKMS:    $(RC_DKMS_DIR)"
	@echo "  Stable Utils: $(STABLE_UTILS_DIR)"
	@echo "  Stable DKMS:  $(STABLE_DKMS_DIR)"

# List files that would be installed
list-files:
	@echo "$(BLUE)Files in RC packages (would be installed):$(NC)"
	@if [ -f "$(RC_UTILS_PKG)" ]; then \
		echo "$(YELLOW)zfs-utils-rc:$(NC)"; \
		tar -tzf "$(RC_UTILS_PKG)" 2>/dev/null | grep -v "^\.PKGINFO\|^\.BUILDINFO\|^\.MTREE" | head -20; \
		echo "  ... (showing first 20 files)"; \
	else \
		echo "$(RED)RC utils package not found$(NC)"; \
	fi
	@echo ""
	@if [ -f "$(RC_DKMS_PKG)" ]; then \
		echo "$(YELLOW)zfs-dkms-rc:$(NC)"; \
		tar -tzf "$(RC_DKMS_PKG)" 2>/dev/null | grep -v "^\.PKGINFO\|^\.BUILDINFO\|^\.MTREE" | head -20; \
		echo "  ... (showing first 20 files)"; \
	else \
		echo "$(RED)RC DKMS package not found$(NC)"; \
	fi

# Show all installed ZFS files on system
show-installed:
	@echo "$(BLUE)Currently installed ZFS files on system:$(NC)"
	@if pacman -Q | grep -q "^zfs"; then \
		echo "$(YELLOW)Installed packages:$(NC)"; \
		pacman -Q | grep "^zfs"; \
		echo ""; \
		echo "$(YELLOW)File count by package:$(NC)"; \
		for pkg in $$(pacman -Q | grep "^zfs" | awk '{print $$1}'); do \
			count=$$(pacman -Ql $$pkg | wc -l); \
			echo "  $$pkg: $$count files"; \
		done; \
		echo ""; \
		echo "$(YELLOW)Sample files (first 20):$(NC)"; \
		pacman -Ql $$(pacman -Q | grep "^zfs" | head -1 | awk '{print $$1}') | head -20; \
	else \
		echo "$(RED)No ZFS packages installed$(NC)"; \
	fi

# Completely remove ZFS from system
uninstall-all:
	@echo "$(RED)WARNING: This will completely remove ALL ZFS packages$(NC)"
	@echo "$(YELLOW)This includes: zfs-utils, zfs-dkms, and all variants$(NC)"
	@echo ""
	@pacman -Q | grep "^zfs" || echo "No ZFS packages installed"
	@echo ""
	@read -p "Are you sure you want to remove ALL ZFS? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(YELLOW)Removing all ZFS packages...$(NC)"; \
		sudo pacman -Rns $$(pacman -Q | grep "^zfs" | awk '{print $$1}') 2>/dev/null || true; \
		echo "$(GREEN)✓ ZFS removed$(NC)"; \
	else \
		echo "$(YELLOW)Uninstall cancelled$(NC)"; \
	fi

# Verify system is clean (no stray ZFS files)
verify-clean:
	@echo "$(BLUE)Verifying system is clean of ZFS...$(NC)"
	@echo ""
	@echo "$(YELLOW)Checking for ZFS packages:$(NC)"
	@if pacman -Q | grep -q "^zfs"; then \
		echo "$(RED)✗ ZFS packages still installed:$(NC)"; \
		pacman -Q | grep "^zfs"; \
	else \
		echo "$(GREEN)✓ No ZFS packages installed$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Checking for ZFS kernel module:$(NC)"
	@if lsmod | grep -q "^zfs "; then \
		echo "$(RED)✗ ZFS module still loaded$(NC)"; \
	else \
		echo "$(GREEN)✓ ZFS module not loaded$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Checking for stray ZFS files in /usr/lib:$(NC)"
	@stray=$$(find /usr/lib -name "*zfs*" 2>/dev/null | wc -l); \
	if [ $$stray -gt 0 ]; then \
		echo "$(RED)✗ Found $$stray ZFS-related files$(NC)"; \
		find /usr/lib -name "*zfs*" 2>/dev/null | head -5; \
		echo "  ... (showing first 5)"; \
	else \
		echo "$(GREEN)✓ No stray ZFS files in /usr/lib$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Checking for DKMS modules:$(NC)"
	@if [ -d /var/lib/dkms/zfs ]; then \
		echo "$(RED)✗ ZFS DKMS directory exists$(NC)"; \
	else \
		echo "$(GREEN)✓ No ZFS DKMS directory$(NC)"; \
	fi

# Check that build process doesn't pollute system
check-build:
	@echo "$(BLUE)Checking build cleanliness...$(NC)"
	@echo ""
	@echo "$(YELLOW)Build artifacts (should be in repo only):$(NC)"
	@echo "  Source dirs: packages/*/src/"
	@ls -d packages/_utils/*/src packages/dkms/*/src 2>/dev/null | head -5 || echo "  None found"
	@echo ""
	@echo "  Build dirs: packages/*/pkg/"
	@ls -d packages/_utils/*/pkg packages/dkms/*/pkg 2>/dev/null | head -5 || echo "  None found"
	@echo ""
	@echo "  Package files: *.pkg.tar.zst"
	@find packages -name "*.pkg.tar.zst" | wc -l | xargs echo "  Found" | sed 's/$$/packages/'
	@echo ""
	@echo "$(GREEN)✓ All build artifacts are contained in repository$(NC)"
	@echo "$(GREEN)✓ No system files are modified during build$(NC)"
