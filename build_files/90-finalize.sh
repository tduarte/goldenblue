#!/usr/bin/env bash
# Config files, services, signature policy and cleanup. Runs last so package
# installs can't overwrite our files.
set -euxo pipefail
source /ctx/lib.sh

log "System files"
cp -avf /ctx/system_files/. /
glib-compile-schemas /usr/share/glib-2.0/schemas
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

log "Services"
systemctl enable flatpak-preinstall.service

log "Signature policy for ghcr.io/tduarte/goldenblue"
# Lets `bootc switch --enforce-container-sigpolicy` and GNOME Software's
# updates verify our cosign signature (key: /etc/pki/containers/goldenblue.pub).
policy=/etc/containers/policy.json
jq '.transports.docker["ghcr.io/tduarte/goldenblue"] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/goldenblue.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]' "$policy" >"${policy}.new"
mv "${policy}.new" "$policy"

log "Cleanup"
# /var/cache, /var/log and /tmp are build mounts and never reach the image.
dnf5 clean all
rm -rf /var/lib/dnf /var/tmp/* /root/.cache /root/.npm
