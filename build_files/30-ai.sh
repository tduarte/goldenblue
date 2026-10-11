#!/usr/bin/env bash
# AI stack: ROCm runtime, llama.cpp (prebuilt in Containerfile.llama), coding agents.
set -euxo pipefail
source /ctx/lib.sh

log "ROCm runtime"
# Same swap bazzite-dx does: Mesa's rusticl OpenCL out, ROCm OpenCL in.
dnf5 -y remove mesa-libOpenCL || true
dnf5 -y install --setopt=install_weak_deps=False \
    rocm-hip rocm-runtime rocm-comgr rocblas hipblas \
    rocm-opencl rocm-clinfo rocminfo rocm-smi amdsmi \
    libgomp

log "llama.cpp ${LLAMA_TAG}"
# /usr/lib/llama.cpp was copied in from the goldenblue-llamacpp image.
test -x /usr/lib/llama.cpp/bin/llama-server
for bin in /usr/lib/llama.cpp/bin/*; do
    ln -sf "../lib/llama.cpp/bin/$(basename "$bin")" "/usr/bin/$(basename "$bin")"
done
component llama.cpp /usr/lib/llama.cpp

log "Claude Code ${CLAUDE_CODE_VERSION}"
rpm --import https://downloads.claude.ai/keys/claude-code.asc
cat >/etc/yum.repos.d/claude-code.repo <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
dnf5 -y install "claude-code-${CLAUDE_CODE_VERSION}"
# The image delivers updates; don't ship the repo (dnf can't write /usr at runtime).
rm -f /etc/yum.repos.d/claude-code.repo

log "oh-my-pi ${OMP_VERSION}"
tmp="$(mktemp -d)"
base="https://github.com/can1357/oh-my-pi/releases/download/v${OMP_VERSION}"
fetch "${base}/omp-linux-x64" "${tmp}/omp-linux-x64"
fetch "${base}/SHA256SUMS.txt" "${tmp}/SHA256SUMS.txt"
(cd "$tmp" && grep ' omp-linux-x64$' SHA256SUMS.txt | sha256sum -c -)
install -Dm755 "${tmp}/omp-linux-x64" /usr/bin/omp
component oh-my-pi /usr/bin/omp
rm -rf "$tmp"

log "opencode ${OPENCODE_VERSION}"
tmp="$(mktemp -d)"
fetch "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64.tar.gz" "${tmp}/opencode.tar.gz"
tar -xzf "${tmp}/opencode.tar.gz" -C "$tmp" opencode
install -Dm755 "${tmp}/opencode" /usr/bin/opencode
component opencode /usr/bin/opencode
rm -rf "$tmp"
