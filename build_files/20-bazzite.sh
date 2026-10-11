#!/usr/bin/env bash
# Bazzite adjustments: GNOME Software replaces Bazaar and handles OS updates;
# our extension set replaces Bazzite's enabled list.
set -euxo pipefail
source /ctx/lib.sh

SCHEMAS=/usr/share/glib-2.0/schemas
DCONF_GLOBAL=/etc/dconf/db/distro.d/00-bazzite-desktop-silverblue-global
DCONF_LOCK=/etc/dconf/db/distro.d/locks/00-bazzite-desktop-silverblue-global-lock

log "Replace Bazaar with GNOME Software"
dnf5 -y remove bazaar
rm -rf /usr/share/ublue-os/bazaar \
    /usr/share/gnome-shell/extensions/bazaar-integration@kolunmi.github.io
dnf5 -y install gnome-software gnome-software-rpm-ostree

# Bazzite turns GNOME Software's updates off and locks the keys.
sed -i '\#^/org/gnome/software/#d' "$DCONF_LOCK"
sed -i "s#^menu-button-software-center=.*#menu-button-software-center='/usr/bin/gnome-software'#" "$DCONF_GLOBAL"
for f in "$SCHEMAS/zz0-01-bazzite-desktop-silverblue-dash.gschema.override" \
    /etc/xdg/mimeapps.list /etc/xdg/mineapps.list; do
    if [[ -f "$f" ]]; then
        sed -i 's#io\.github\.kolunmi\.Bazaar\.desktop#org.gnome.Software.desktop#g' "$f"
    fi
done
# First-login setup would re-enable the removed extension (and pin the
# enabled-extensions list into the user's dconf).
sed -i 's#^\(\s*\)gnome-extensions enable bazaar-integration@kolunmi.github.io#\1true \# goldenblue: Bazaar removed#' \
    /usr/libexec/bazzite-user-setup

log "Updates: GNOME Software instead of uupd"
# Bazzite's uupd timer updates the OS and Flatpaks daily; GNOME Software now
# does both, so turn the timer off to avoid two updaters. `ujust update`
# still works on demand. rpm-ostreed stays at AutomaticUpdatePolicy=none:
# GNOME Software drives downloads and asks before rebooting.
systemctl disable uupd.timer

log "Terminal: Ghostty instead of Ptyxis in shortcuts"
sed -i "s#^command='ptyxis --new-window'#command='ghostty'#" "$DCONF_GLOBAL"
sed -i 's#org\.gnome\.Ptyxis\.desktop#com.mitchellh.ghostty.desktop#g' \
    "$SCHEMAS/zz0-01-bazzite-desktop-silverblue-dash.gschema.override"
