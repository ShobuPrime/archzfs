# ArchZFS - OpenZFS DKMS Packages for Arch Linux

Build OpenZFS packages (stable and RC versions) for any Arch Linux kernel using DKMS.

## Quick Start

```bash
# Install dependencies
sudo pacman -S base-devel python python-setuptools python-cffi dkms

# Build packages
sudo make rc          # For RC versions
# OR
sudo make stable      # For stable versions

# Install
make install-rc       # Or install-stable
make verify
```

See `make help` for all commands.

## Using as a Pacman Repository

Two separate repositories are available - choose stable or RC based on your needs:

### Stable Repository (Recommended)

```ini
# Add to /etc/pacman.conf
[archzfs]
SigLevel = Optional TrustAll
Server = https://github.com/YOUR_USERNAME/archzfs/releases/download/experimental
```

Install:
```bash
sudo pacman -Sy archzfs/zfs-dkms archzfs/zfs-utils
sudo systemctl enable zfs.target
```

### RC Repository (Testing/Compatibility)

```ini
# Add to /etc/pacman.conf
[archzfs-rc]
SigLevel = Optional TrustAll
Server = https://github.com/YOUR_USERNAME/archzfs/releases/download/experimental-rc
```

Install:
```bash
sudo pacman -Sy archzfs-rc/zfs-dkms-rc archzfs-rc/zfs-utils-rc
sudo systemctl enable zfs.target
```

See [Appendix C](Claude.md#appendix-c-using-the-pacman-repository) for complete setup guide.

## Key Features

- ✅ **RC Build Support** - Fixed release candidate package builds
- ✅ **Modern Arch Compatibility** - Updated for `/usr/lib` paths
- ✅ **Makefile Automation** - Simple build and install commands
- ✅ **Helper Script** - Build any OpenZFS version: `./build-openzfs-version.sh`
- ✅ **GitHub Actions** - Automated builds on release tags
- ✅ **Pacman Repository** - Host packages via GitHub Releases

## Documentation

- **[Claude.md](Claude.md)** - Complete guide with fixes, troubleshooting, and appendices
  - Appendix A: Quick Start Guide
  - Appendix B: Build Safety Guide
- **[Makefile](Makefile)** - Run `make help` for commands
- **[build-openzfs-version.sh](build-openzfs-version.sh)** - Build any version

## Critical Fixes Included

### RC Builds
In `src/kernels/dkms.sh` and `src/kernels/_utils.sh`:
```bash
zfs_workdir="\${srcdir}/zfs-\${pkgver/_/-}"  # ✅ CORRECT
# NOT: zfs_workdir="\${srcdir}/zfs-\${pkgver/_rc*/}"  # ❌ WRONG
```

### Modern Arch Paths
In `src/zfs-utils/zfs-utils.initcpio.install`:
- All `/lib/` paths updated to `/usr/lib/`
- Hash updated in `conf.sh`

## FAQ

**Q: Do I need the `zfs` hook in mkinitcpio?**
A: Only if your root filesystem is on ZFS. For BTRFS/ext4 roots, do NOT add it.

**Q: How do pools auto-import?**
A: Enable systemd services: `sudo systemctl enable zfs.target`

**Q: Is building safe?**
A: Yes. Building only affects the repository. Use `make check-build` to verify.

See [Claude.md](Claude.md) for complete documentation.

## Resources

- **OpenZFS**: https://openzfs.org/
- **Releases**: https://github.com/openzfs/zfs/releases
- **Arch Wiki**: https://wiki.archlinux.org/title/ZFS
- **Original archzfs**: https://github.com/archzfs/archzfs

## License

- Arch Linux packages: MIT License
- OpenZFS: CDDL License
