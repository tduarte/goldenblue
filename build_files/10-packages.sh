#!/usr/bin/env bash
# RPM packages: shell, dev tooling, Ghostty, Brave Origin.
set -euxo pipefail
source /ctx/lib.sh

log "Shell and dev tooling (Fedora)"
dnf5 -y install \
    attr unzip jq gtk-update-icon-cache \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    uv \
    nodejs24 nodejs24-bin nodejs24-npm nodejs24-npm-bin \
    rustup golang \
    gh git-lfs \
    podman-compose podman-docker docker-compose

log "Ghostty ${GHOSTTY_VERSION} (Terra, already configured but disabled in Bazzite)"
dnf5 -y install --enable-repo=terra ghostty

log "Brave Origin"
# The RPM installs into /opt, which on bootc is /var/opt (not part of the
# image). Install into a real /opt, then move it under /usr/lib; a tmpfiles
# link makes /opt/brave.com resolve to it at runtime.
opt_was_link=false
if [[ -L /opt ]]; then
    opt_was_link=true
    rm /opt
fi
mkdir -p /opt
curl -fsSL --retry 5 -o /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 -y install brave-origin
mv /opt/brave.com /usr/lib/brave.com
# Moved files are no longer at their rpmdb paths, so rechunk would treat them
# as unpackaged; give them their own chunk.
component brave-origin /usr/lib/brave.com
if [[ "$opt_was_link" == true ]]; then
    rmdir /opt
    ln -s var/opt /opt
fi
# Brave's cron job re-adds its repo; updates come with the image instead.
rm -f /etc/yum.repos.d/brave-browser.repo /etc/cron.daily/brave-origin
