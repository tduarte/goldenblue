# goldenblue — image spec

Custom bootc image built on Bazzite GNOME, with AI tooling in the system layer.

## Base & build
| Item | Decision |
|---|---|
| Base image | `ghcr.io/ublue-os/bazzite-gnome:stable` (AMD, desktop/laptop) |
| Kernel | Bazzite kernel (unchanged) |
| Registry | `ghcr.io/tduarte/goldenblue` (public repo `tduarte/goldenblue`) |
| Update size | Rechunk the final image + reproducible builds (`SOURCE_DATE_EPOCH`, normalized mtimes, no caches/pyc/logs) |
| Build trigger | Daily fingerprint check: Bazzite digest + repo commit + versions of custom packages. Build/push only when something changed |
| Signing | cosign |

## AI (AMD / ROCm)
| Item | Delivery |
|---|---|
| ROCm/HIP runtime libs | Fedora RPMs in image |
| llama.cpp | In `/usr`, ROCm (HIP) + Vulkan backends, `llama-server` systemd unit (off by default) |
| ComfyUI | `ujust install-comfyui` → uv venv in `~/.local` with PyTorch-ROCm |
| Unsloth | `ujust install-unsloth` → uv venv with PyTorch-ROCm |
| Claude Code | `/usr`, built-in auto-updater disabled (image updates it) |
| oh-my-pi | `/usr` |
| opencode | Single binary in `/usr` |

## Desktop
| Item | Decision |
|---|---|
| Editor | Zed (`/usr`) |
| Browsers | Zen, Brave Origin (system layer); Firefox Flatpak left as-is |
| Terminal | Ghostty |
| App store | GNOME Software replaces Bazaar; handles Flatpaks **and** OS image updates (rpm-ostree plugin). Bazzite's auto-updater adjusted so the two don't conflict |
| Icons | WhiteSur |
| Cursor | Bibata Modern Ice |

## GNOME extensions
- **Enabled:** Hot Edge, AppIndicator, Caffeine, Alphabetical App Grid
- **Bazzite defaults** (Dash to Dock, Blur my Shell, Logo Menu, …): left installed, disabled by default
- Defaults applied via system dconf so users can override

## Shell & dev
- zsh as default shell + Oh My Zsh (system-wide)
- Dev runtimes: uv, node/bun, rustup, go
- Containers & dev: podman-compose, distrobox, docker-compatible CLI, gh, git-lfs, just

## Gaming
- Launchers: Steam + Lutris (Bazzite's system-layer packages, kept)
- Extra launchers/tools go in as Flatpaks, not the system layer
- ProtonPlus (Flatpak) preinstalled for managing Proton-GE / Proton-CachyOS
- Otherwise Bazzite defaults, no additions

## Resolved during research (2026-10-11)
- Base is Fedora 44 / GNOME 50; Fedora ROCm is 7.1
- llama.cpp: upstream's ROCm binaries target ROCm 10, so it's compiled from source against Fedora's ROCm (Containerfile.llama), rebuilt only when llama.cpp or ROCm changes
- Unsloth supports RDNA2–4 via `unsloth[amd]` + PyTorch ROCm wheels; installed per user with `ujust install-unsloth`
- oh-my-pi = can1357/oh-my-pi (`omp`), single binary from GitHub releases
- Brave Origin = `brave-origin` RPM from Brave's repo; installs to /opt, relocated to /usr/lib/brave.com
- Zen: official tarball (COPRs install to /opt or lag)
- Ghostty from Terra (preconfigured in Bazzite); Zed, bun, WhiteSur, Bibata, Alphabetical App Grid from pinned upstream releases
- Bazzite already ships AppIndicator, Caffeine and Hot Edge; only Alphabetical App Grid is added

## Unverified (check on first boot)
- GNOME Software's rpm-ostree plugin applying updates for a signed container image
- `ZED_UPDATE_EXPLANATION` / `PI_CONFIG_FILES` suppressing Zed's and omp's update prompts
