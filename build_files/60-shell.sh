#!/usr/bin/env bash
# zsh + Oh My Zsh as the default shell for new users.
set -euxo pipefail
source /ctx/lib.sh

log "Oh My Zsh"
# Read-only in /usr: Oh My Zsh skips self-updates when $ZSH isn't writable, and
# the image ships the newest commit each time it's rebuilt.
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh
git -C /usr/share/oh-my-zsh rev-parse HEAD >/usr/share/oh-my-zsh/.goldenblue-commit
rm -rf /usr/share/oh-my-zsh/.git
component oh-my-zsh /usr/share/oh-my-zsh

# New users get zsh (the template .zshrc comes from system_files/etc/skel).
if grep -q '^SHELL=' /etc/default/useradd; then
    sed -i 's#^SHELL=.*#SHELL=/usr/bin/zsh#' /etc/default/useradd
else
    echo 'SHELL=/usr/bin/zsh' >>/etc/default/useradd
fi
