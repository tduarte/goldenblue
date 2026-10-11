#!/usr/bin/env bash
# Look and feel: WhiteSur icons, Bibata Modern Ice cursor, Alphabetical App Grid.
# Defaults are applied by system_files/usr/share/glib-2.0/schemas/zz1-goldenblue.gschema.override.
set -euxo pipefail
source /ctx/lib.sh

log "WhiteSur icons ${WHITESUR_TAG}"
tmp="$(mktemp -d)"
fetch "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/tags/${WHITESUR_TAG}.tar.gz" "${tmp}/whitesur.tar.gz"
tar -xzf "${tmp}/whitesur.tar.gz" -C "$tmp" --strip-components=1
(cd "$tmp" && ./install.sh -d /usr/share/icons -t default)
component whitesur-icons /usr/share/icons/WhiteSur*
rm -rf "$tmp"

log "Bibata cursors ${BIBATA_VERSION}"
tmp="$(mktemp -d)"
fetch "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VERSION}/Bibata-Modern-Ice.tar.xz" "${tmp}/bibata.tar.xz"
tar -xJf "${tmp}/bibata.tar.xz" -C /usr/share/icons
component bibata-cursors /usr/share/icons/Bibata-Modern-Ice
rm -rf "$tmp"

log "Alphabetical App Grid ${ALPHAGRID_VERSION}"
uuid="AlphabeticalAppGrid@stuarthayhurst"
dest="/usr/share/gnome-shell/extensions/${uuid}"
tmp="$(mktemp -d)"
fetch "https://github.com/stuarthayhurst/alphabetical-grid-extension/releases/download/v${ALPHAGRID_VERSION}/${uuid}.shell-extension.zip" "${tmp}/ext.zip"
mkdir -p "$dest"
unzip -q -o "${tmp}/ext.zip" -d "$dest"
glib-compile-schemas "${dest}/schemas"
component gnome-extensions-goldenblue "$dest"
rm -rf "$tmp"
