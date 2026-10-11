# goldenblue

A custom [bootc](https://bootc-dev.github.io/bootc/) image built on
[Bazzite GNOME](https://bazzite.gg) for AMD desktops. It keeps Bazzite's gaming
kernel and Steam/Lutris setup, and adds an AI toolchain to the system layer.

Full list of choices: [SPEC.md](SPEC.md).

## What's inside

| | |
|---|---|
| **Base** | `ghcr.io/ublue-os/bazzite-gnome:stable` (Bazzite kernel, Steam, Lutris) |
| **AI** | ROCm runtime, llama.cpp (ROCm + Vulkan), Claude Code, oh-my-pi (`omp`), opencode |
| **AI, per user** | `ujust install-comfyui`, `ujust install-unsloth` (uv venvs with PyTorch-ROCm) |
| **Apps** | Zed, Zen Browser, Brave Origin, Ghostty |
| **Store / updates** | GNOME Software (replaces Bazaar), handles Flatpaks and OS updates |
| **Look** | WhiteSur icons, Bibata Modern Ice cursor |
| **Extensions** | AppIndicator, Caffeine, Hot Edge, Alphabetical App Grid (Bazzite's others are installed but off) |
| **Shell / dev** | zsh + Oh My Zsh, uv, Node 24, bun, rustup, Go, gh, git-lfs, podman-compose, docker CLI shim |
| **Flatpaks** | ProtonPlus, installed on first boot |

## Install

**From an existing Bazzite (or other Fedora Atomic) install:**

```bash
sudo bootc switch ghcr.io/tduarte/goldenblue:latest
```

Reboot. Then switch again with signature verification turned on, so every
later update is checked against [`cosign.pub`](cosign.pub):

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/tduarte/goldenblue:latest
```

**Fresh install:** run the *Build installer ISO* workflow (Actions tab) and
download the artifact. You can also build it locally on Fedora with
`just build-iso ghcr.io/tduarte/goldenblue latest`.

A regular (non-atomic) Fedora Workstation can't switch directly. Install from the ISO.

## After installing

```bash
ujust zsh-default          # make zsh your login shell (new users get it already)
ujust enable-llama-server  # llama-server user service on 127.0.0.1:8080
ujust install-comfyui      # then: comfyui
ujust install-unsloth      # then: unsloth studio
```

Pick the llama.cpp backend with `llama-server --list-devices` and
`--device ROCm0` or `--device Vulkan0`. Cards outside the built targets
(RDNA2–4) may need `HSA_OVERRIDE_GFX_VERSION` (e.g. `10.3.0` or `11.0.0`).

## How updates stay small

1. **Rechunking.** After every build, `rpm-ostree compose build-chunked-oci`
   splits the image into up to 127 layers grouped by package, reusing the
   previous build's layout. An update downloads only the chunks whose
   packages changed.
2. **Components for non-RPM files.** Apps installed from tarballs (Zed, Zen,
   llama.cpp, omp, opencode, bun, themes, Oh My Zsh) are tagged with a
   `user.component` xattr, so each gets its own chunk instead of sharing one
   "unpackaged" layer.
3. **No pointless builds.** A daily job hashes the Bazzite base digest, the
   build inputs in this repo, and the upstream versions from
   [`resolve-versions.sh`](build_files/resolve-versions.sh). It builds only
   when that hash differs from the published image's label, or when the image
   is 7+ days old (to pick up Fedora updates for added packages).
4. **llama.cpp is built separately.** Compiling the HIP kernels is slow, so it
   runs only when the llama.cpp release or Fedora's ROCm version changes. The
   result is published as `ghcr.io/tduarte/goldenblue-llamacpp`.

## Layout

```
Containerfile          final image: base + llama.cpp + build_files/build.sh
Containerfile.llama    llama.cpp (ROCm + Vulkan) build
build_files/           numbered build steps (10-packages … 90-finalize)
  resolve-versions.sh  upstream versions → versions.env (+ fingerprint)
system_files/          copied over / at the end of the build
.github/workflows/     build.yml (check → llama → build), build-iso.yml
```

## Local builds (Fedora with podman)

```bash
just versions      # resolve upstream versions
just build         # pulls the published llama.cpp image (or: just build-llama)
just rechunk
just build-vm && just run-vm
```

## Signing

Images are signed with cosign. The private key is the `SIGNING_SECRET`
repository secret; the public key is [`cosign.pub`](cosign.pub) and
`/etc/pki/containers/goldenblue.pub` in the image.
