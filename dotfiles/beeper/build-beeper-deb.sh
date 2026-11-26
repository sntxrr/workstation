#!/usr/bin/env bash
# Repackage the official Beeper AppImage as a .deb (installs to /opt/beeper).
# Extracts with unsquashfs — never executes the AppImage.
# Usage: build-beeper-deb <AppImage> <outdir> [version]   (needs squashfs-tools, dpkg-deb)
set -euo pipefail
umask 022
APPIMAGE="$1"; OUT="$2"
VER="${3:-4.3.352}"
WORK="$(mktemp -d "$OUT/work.XXXX")"

# AppImage type 2: squashfs starts right after the ELF runtime (end of section headers).
OFFSET=$(python3 -I -c '
import struct,sys
d=open(sys.argv[1],"rb").read(64)
shoff,=struct.unpack_from("<Q",d,0x28); shentsize,shnum=struct.unpack_from("<HH",d,0x3A)
print(shoff+shentsize*shnum)' "$APPIMAGE")
unsquashfs -q -o "$OFFSET" -d "$WORK/root" "$APPIMAGE"

PKG="$WORK/pkg"
mkdir -p "$PKG/DEBIAN" "$PKG/opt" "$PKG/usr/bin" "$PKG/usr/share/applications" "$PKG/usr/share/icons/hicolor/512x512/apps"
cp -a "$WORK/root" "$PKG/opt/beeper"
rm -f "$PKG/opt/beeper/AppRun" "$PKG/opt/beeper/.DirIcon"

BIN=$(basename "$(grep -m1 '^Exec=' "$WORK"/root/*.desktop | sed 's/^Exec=//; s/ .*//; s/AppRun/beepertexts/')")
[ -x "$PKG/opt/beeper/$BIN" ] || BIN=$(cd "$PKG/opt/beeper" && ls | grep -iE '^beeper' | grep -v -E '\.(png|desktop)$' | head -1)
# Electron sandbox helper needs setuid root
[ -f "$PKG/opt/beeper/chrome-sandbox" ] && chmod 4755 "$PKG/opt/beeper/chrome-sandbox"
ln -s "/opt/beeper/$BIN" "$PKG/usr/bin/beeper"

ICON=$(ls "$WORK"/root/*.png | head -1)
cp "$ICON" "$PKG/usr/share/icons/hicolor/512x512/apps/beeper.png"
sed -e 's|^Exec=[^ ]*|Exec=/opt/beeper/'"$BIN"'|' -e 's|^Icon=.*|Icon=beeper|' -e 's| --no-sandbox||' \
    "$WORK"/root/*.desktop > "$PKG/usr/share/applications/beeper.desktop"

cat > "$PKG/DEBIAN/control" <<EOF
Package: beeper
Version: $VER
Architecture: amd64
Maintainer: local build <root@localhost>
Section: net
Priority: optional
Depends: libgtk-3-0t64 | libgtk-3-0, libnss3, libxss1, libasound2t64 | libasound2, libgbm1
Description: Beeper Desktop (repackaged from official AppImage)
EOF
cat > "$PKG/DEBIAN/postinst" <<'EOF'
#!/bin/sh
command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
EOF
chmod 755 "$PKG/DEBIAN/postinst"

dpkg-deb --root-owner-group --build "$PKG" "$OUT/beeper_${VER}_amd64.deb"
echo "Binary: /opt/beeper/$BIN"
rm -rf "$WORK"
