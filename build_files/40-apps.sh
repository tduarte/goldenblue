#!/usr/bin/env bash
# Apps from upstream tarballs: Zed, Zen Browser, bun.
set -euxo pipefail
source /ctx/lib.sh

log "Zed ${ZED_VERSION}"
tmp="$(mktemp -d)"
fetch "https://github.com/zed-industries/zed/releases/download/v${ZED_VERSION}/zed-linux-x86_64.tar.gz" "${tmp}/zed.tar.gz"
tar -xzf "${tmp}/zed.tar.gz" -C /usr/lib
# Wrapper rather than a symlink: ZED_UPDATE_EXPLANATION makes Zed skip its
# self-updater (it can't write /usr anyway), however Zed is launched.
cat >/usr/bin/zed <<'EOF'
#!/usr/bin/bash
export ZED_UPDATE_EXPLANATION="Zed is updated with the goldenblue image"
exec /usr/lib/zed.app/bin/zed "$@"
EOF
chmod 755 /usr/bin/zed
install -Dm644 /usr/lib/zed.app/share/applications/dev.zed.Zed.desktop /usr/share/applications/dev.zed.Zed.desktop
for size in 512x512 1024x1024; do
    install -Dm644 "/usr/lib/zed.app/share/icons/hicolor/${size}/apps/zed.png" "/usr/share/icons/hicolor/${size}/apps/zed.png"
done
component zed /usr/lib/zed.app
rm -rf "$tmp"

log "Zen Browser ${ZEN_VERSION}"
tmp="$(mktemp -d)"
fetch "https://github.com/zen-browser/desktop/releases/download/${ZEN_VERSION}/zen.linux-x86_64.tar.xz" "${tmp}/zen.tar.xz"
tar -xJf "${tmp}/zen.tar.xz" -C /usr/lib
ln -sf ../lib/zen/zen /usr/bin/zen
# Updates come with the image; the bundled updater can't write /usr.
install -Dm644 /dev/stdin /usr/lib/zen/distribution/policies.json <<'EOF'
{
  "policies": {
    "DisableAppUpdate": true,
    "AppAutoUpdate": false,
    "ManualAppUpdateOnly": true,
    "BackgroundAppUpdate": false
  }
}
EOF
for size in 16 32 48 64 128; do
    install -Dm644 "/usr/lib/zen/browser/chrome/icons/default/default${size}.png" "/usr/share/icons/hicolor/${size}x${size}/apps/zen.png"
done
cat >/usr/share/applications/zen.desktop <<'EOF'
[Desktop Entry]
Name=Zen Browser
Comment=Experience tranquillity while browsing the web without people tracking you!
Exec=zen %u
Icon=zen
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;application/x-xpinstall;application/pdf;application/json;
StartupWMClass=zen
Categories=Network;WebBrowser;
StartupNotify=true
Terminal=false
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=Open a New Window
Exec=zen --new-window %u

[Desktop Action new-private-window]
Name=Open a New Private Window
Exec=zen --private-window %u
EOF
component zen /usr/lib/zen
rm -rf "$tmp"

log "bun ${BUN_VERSION}"
tmp="$(mktemp -d)"
base="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}"
fetch "${base}/bun-linux-x64.zip" "${tmp}/bun-linux-x64.zip"
fetch "${base}/SHASUMS256.txt" "${tmp}/SHASUMS256.txt"
(cd "$tmp" && grep ' bun-linux-x64.zip$' SHASUMS256.txt | sha256sum -c -)
unzip -q "${tmp}/bun-linux-x64.zip" -d "$tmp"
install -Dm755 "${tmp}/bun-linux-x64/bun" /usr/bin/bun
ln -sf bun /usr/bin/bunx
component bun /usr/bin/bun
rm -rf "$tmp"
