#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ID="com.aw.pst-installer"

usage() {
    echo "Usage: $0 <path-to-awpstXXX-darwin.tgz>"
    echo ""
    echo "Example: $0 /path/to/awpst999-darwin.tgz"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

TGZ_PATH="$1"

if [ ! -f "$TGZ_PATH" ]; then
    echo "Error: File not found: $TGZ_PATH"
    exit 1
fi

TGZ_NAME="$(basename "$TGZ_PATH")"

# Validate filename pattern: awpstNNN-darwin.tgz
case "$TGZ_NAME" in
    awpst*-darwin.tgz) ;;
    *)
        echo "Error: Filename must match pattern awpstXXX-darwin.tgz"
        echo "Got: $TGZ_NAME"
        exit 1
        ;;
esac

# Extract version: awpst800-darwin.tgz -> 800
VERSION="${TGZ_NAME#awpst}"
VERSION="${VERSION%%-darwin.tgz}"

# Convert to dotted version for pkgbuild (e.g. 800 -> 8.0.0, 1234 -> 12.3.4)
case ${#VERSION} in
    1) PKG_VERSION="$VERSION.0.0" ;;
    2) PKG_VERSION="${VERSION:0:1}.${VERSION:1:1}.0" ;;
    3) PKG_VERSION="${VERSION:0:1}.${VERSION:1:1}.${VERSION:2:1}" ;;
    *) PKG_VERSION="${VERSION:0:$((${#VERSION}-2))}.${VERSION:$((${#VERSION}-2)):1}.${VERSION:$((${#VERSION}-1)):1}" ;;
esac

OUTPUT_PKG="${SCRIPT_DIR}/awpst${VERSION}-installer.pkg"

echo "=== AW PST Package Builder ==="
echo "  Archive:     $TGZ_NAME"
echo "  Version:     $VERSION (pkg version $PKG_VERSION)"
echo "  Output:      $OUTPUT_PKG"
echo ""

# Create a clean temporary build directory
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

# -- Payload: place tgz at private/tmp/ so it lands at /private/tmp/ on disk --
# Clear the Gatekeeper quarantine flag on the downloaded archive first, so it
# can't be carried into the package (and on to the files extracted from it).
if xattr -p com.apple.quarantine "$TGZ_PATH" >/dev/null 2>&1; then
    echo "Clearing com.apple.quarantine on $TGZ_NAME"
    xattr -d com.apple.quarantine "$TGZ_PATH"
fi

# Don't let cp/pkgbuild generate ._ AppleDouble files for any leftover metadata
export COPYFILE_DISABLE=1

mkdir -p "$BUILD_DIR/payload/tmp"
# -X: do not copy extended attributes or resource forks
cp -X "$TGZ_PATH" "$BUILD_DIR/payload/tmp/"

# -- Scripts: copy the postinstall script --
mkdir -p "$BUILD_DIR/scripts"
cp "$SCRIPT_DIR/payload/Scripts/postinstall" "$BUILD_DIR/scripts/postinstall"
chmod +x "$BUILD_DIR/scripts/postinstall"

# -- Strip every extended attribute from the staging tree and verify --
xattr -cr "$BUILD_DIR"
if xattr -lr "$BUILD_DIR" 2>/dev/null | grep -q "com.apple.quarantine"; then
    echo "Error: quarantine flag still present in the staging tree:"
    xattr -lr "$BUILD_DIR" | grep "com.apple.quarantine"
    exit 1
fi
echo "Staging tree is free of quarantine flags"

# -- Build the pkg --
pkgbuild \
    --root "$BUILD_DIR/payload" \
    --install-location /private \
    --scripts "$BUILD_DIR/scripts" \
    --identifier "$PKG_ID" \
    --version "$PKG_VERSION" \
    "$OUTPUT_PKG"

# The pkg is built locally so it shouldn't be quarantined, but make sure
xattr -d com.apple.quarantine "$OUTPUT_PKG" 2>/dev/null || true

echo ""
echo "Done! Package created at:"
echo "  $OUTPUT_PKG"
echo ""
echo "Install with:"
echo "  sudo installer -pkg \"$OUTPUT_PKG\" -target /"
