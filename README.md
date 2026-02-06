# p5PKGbuild

TL;DR

Build your own macOS PKG installer from the Archiware provided tgz unix archive

# AW PST macOS Installer Builder

Builds a macOS `.pkg` installer from an `awpstXXX-darwin.tgz` archive. When the resulting package is installed, it deploys the archive to the target Mac and runs a postinstall script that stops any running AW server, extracts the archive into `/usr/local/aw`, and starts the server.

## Requirements

- macOS (uses `pkgbuild` which ships with Xcode Command Line Tools)
- Bash

## Directory Structure

```
p5install/
├── build-pkg.sh                          # Build script
├── payload/
│   └── Scripts/
│       └── postinstall                   # Runs automatically after install
└── README.md
```

## Usage

```bash
./build-pkg.sh <path-to-awpstXXX-darwin.tgz>
```

Example:

```bash
./build-pkg.sh ~/Downloads/awpst999-darwin.tgz
```

This produces `awpst999-installer.pkg` in the same directory as the script.

## Installing the Package

Double-click the `.pkg` file, or install from the command line:

```bash
sudo installer -pkg awpst999-installer.pkg -target /
```

Since the package is unsigned, macOS Gatekeeper will block it if double-clicked. Right-click the `.pkg` and select **Open** to bypass this, or sign it with a Developer ID Installer certificate.

## What the Installer Does

When the `.pkg` is installed on a target Mac, the following happens in order:

1. The `awpstXXX-darwin.tgz` archive is copied to `/private/tmp/`.
2. The `postinstall` script runs automatically and:
   - Creates `/usr/local/aw` if it doesn't exist.
   - Runs `/usr/local/aw/stop-server` if it exists (safe for first-time installs).
   - Extracts the `.tgz` archive into `/usr/local/aw`.
   - Runs `/usr/local/aw/start-server`.
3. All activity is logged to `/var/log/awp_install.log`.

## Version Numbering

The version is parsed from the archive filename. `awpst800-darwin.tgz` yields version `800`, which is mapped to pkg version `8.0.0`. This versioning allows macOS to track installed package versions for upgrades.

## Troubleshooting

- **Install log**: Check `/var/log/awp_install.log` for postinstall output.
- **Verify package contents**: `pkgutil --payload-files awpstXXX-installer.pkg`
- **Check installed version**: `pkgutil --pkg-info com.aw.pst-installer`
