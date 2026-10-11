#!/usr/bin/env bash
# Shared helpers for build scripts. Sourced, not executed.

# Versions resolved by resolve-versions.sh (also used for the CI fingerprint).
# shellcheck source=/dev/null
source /ctx/versions.env

log() { printf '\n==> %s\n' "$*"; }

# fetch URL DEST: download with retries; fails the build on HTTP errors.
fetch() {
    curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors -o "$2" "$1"
}

# component NAME PATH...: tag files with a rechunk component so rpm-ostree's
# build-chunked-oci puts them in their own layer. Without this, every file not
# owned by an RPM lands in one shared chunk and any app update re-downloads all
# of them.
component() {
    local name="$1"
    shift
    # user.* xattrs can't be set on symlinks; regular files are what matter.
    find "$@" -xdev -type f -print0 |
        xargs -0 -r setfattr -n user.component -v "$name"
}

# copr_install OWNER/PROJECT PKG...: install from a COPR, then remove the repo
# file so it does not ship in the image.
copr_install() {
    local copr="$1"
    shift
    dnf5 -y copr enable "$copr"
    dnf5 -y install "$@"
    dnf5 -y copr disable "$copr"
    rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:"${copr/\//:}".repo
}
