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
mkdir -p "$BUILD_DIR/payload/tmp"
cp "$TGZ_PATH" "$BUILD_DIR/payload/tmp/"

# -- Scripts: copy the postinstall script --
mkdir -p "$BUILD_DIR/scripts"
cp "$SCRIPT_DIR/payload/Scripts/postinstall" "$BUILD_DIR/scripts/postinstall"
chmod +x "$BUILD_DIR/scripts/postinstall"

# -- Build the pkg --
pkgbuild \
    --root "$BUILD_DIR/payload" \
    --install-location /private \
    --scripts "$BUILD_DIR/scripts" \
    --identifier "$PKG_ID" \
    --version "$PKG_VERSION" \
    "$OUTPUT_PKG"

echo ""
echo "Done! Package created at:"
echo "  $OUTPUT_PKG"
echo ""
echo "Install with:"
echo "  sudo installer -pkg \"$OUTPUT_PKG\" -target /"
