set dotenv-filename := "image.env"
set dotenv-load

export image_name := env("IMAGE_NAME")
export repo_organization := env("REPO_ORGANIZATION")
export image_desc := env("IMAGE_DESC")
export image_keywords := env("IMAGE_KEYWORDS")
export image_logo_url := env("IMAGE_LOGO_URL")
export default_tag := env("DEFAULT_TAG")
export base_image := env("BASE_IMAGE")
export bib_image := env("BIB_IMAGE")
export image_registry := "ghcr.io/" + repo_organization

alias build-vm := build-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just syntax
[group('Just')]
check:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f "$file"
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just syntax
[group('Just')]
fix:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        just --unstable --fmt -f "$file"
    done
    just --unstable --fmt -f Justfile

# Resolve upstream versions of non-Fedora tools into versions.env
[group('Fingerprint')]
versions:
    build_files/resolve-versions.sh > versions.env
    cat versions.env

# Digest of the base image we build on
[group('Fingerprint')]
base-digest:
    @skopeo inspect --retry-times 3 --no-tags "docker://${base_image}" | jq -r .Digest

# Hash of everything that determines the image contents.
# CI only builds when this differs from the label on the published image.
[group('Fingerprint')]
fingerprint base_digest="":
    #!/usr/bin/env bash
    set -euo pipefail
    digest="{{ base_digest }}"
    [[ -n "$digest" ]] || digest="$(just base-digest)"
    {
        echo "base=${digest}"
        # Build inputs only: README/docs edits don't trigger a new image.
        git ls-files -s -- Containerfile Containerfile.llama build_files system_files image.env
        grep -v '^#' versions.env
    } | sha256sum | cut -d' ' -f1

# Fingerprint label of the currently published image (empty if none)
[group('Fingerprint')]
published-fingerprint tag=default_tag:
    @skopeo inspect --retry-times 3 --no-tags "docker://${image_registry}/${image_name}:{{ tag }}" 2>/dev/null \
        | jq -r '.Labels["io.github.tduarte.goldenblue.fingerprint"] // empty' || true

# Build the image
[group('Build')]
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail

    [[ -f versions.env ]] || just versions
    BASE_DIGEST="$(just base-digest)"
    FINGERPRINT="$(just fingerprint "${BASE_DIGEST}")"
    LLAMA_IMAGE="$(just llama-image)"

    LABELS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        LABELS+=("--label" "org.opencontainers.image.source=https://github.com/${repo_organization}/${image_name}/blob/${GIT_SHA}/Containerfile")
        LABELS+=("--label" "org.opencontainers.image.url=https://github.com/${repo_organization}/${image_name}/tree/${GIT_SHA}")
        LABELS+=("--label" "org.opencontainers.image.version=${tag}.$(date +%Y%m%d)-${GIT_SHA}")
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/${repo_organization}/${image_name}/${GIT_SHA}/README.md")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords=${image_keywords}")
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url=${image_logo_url}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    LABELS+=("--label" "org.opencontainers.image.description=${image_desc}")
    LABELS+=("--label" "org.opencontainers.image.title=${image_name}")
    LABELS+=("--label" "org.opencontainers.image.vendor=${repo_organization}")
    LABELS+=("--label" "io.github.tduarte.goldenblue.fingerprint=${FINGERPRINT}")
    LABELS+=("--label" "io.github.tduarte.goldenblue.base=${base_image}@${BASE_DIGEST}")

    # Pin the base by digest so the image matches the fingerprint exactly.
    podman build \
        "${LABELS[@]}" \
        --build-arg "BASE_IMAGE=${base_image%:*}@${BASE_DIGEST}" \
        --build-arg "LLAMA_IMAGE=${LLAMA_IMAGE}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        --file Containerfile \
        .

# llama.cpp image ref for the current versions.env
[group('llama.cpp')]
llama-image:
    #!/usr/bin/env bash
    set -euo pipefail
    source versions.env
    echo "${image_registry}/${image_name}-llamacpp:${LLAMA_IMAGE_TAG}"

# Build the llama.cpp (ROCm + Vulkan) image. Slow: compiles HIP kernels for RDNA2-4.
[group('llama.cpp')]
build-llama:
    #!/usr/bin/env bash
    set -euxo pipefail
    [[ -f versions.env ]] || just versions
    source versions.env
    podman build \
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
        --build-arg "LLAMA_TAG=${LLAMA_TAG}" \
        --label "org.opencontainers.image.source=https://github.com/${repo_organization}/${image_name}" \
        --label "org.opencontainers.image.description=llama.cpp ${LLAMA_TAG} (ROCm ${ROCM_VERSION} + Vulkan) for ${image_name}" \
        --tag "$(just llama-image)" \
        --file Containerfile.llama \
        .

# Rechunk into package-sized layers so updates only download what changed
[group('Build')]
rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -xeuo pipefail

    GRAPHROOT="$(podman info --format '{{ '{{.Store.GraphRoot}}' }}')"

    # build-chunked-oci starts from a bare rootfs, so carry the labels over.
    LABEL_ARGS=()
    while IFS= read -r label; do
        LABEL_ARGS+=(--label "$label")
    done < <(podman inspect "${target_image}:${tag}" \
        | jq -r '.[0].Config.Labels // {} | to_entries[]
            | select(.key != "ostree.commit" and .key != "ostree.final-diffid")
            | "\(.key)=\(.value)"')

    # Reuse the published image's layer plan when we can, so packages stay in
    # the same chunks from build to build.
    PREV_ARGS=()
    PREVIOUS="${image_registry}/${image_name}:${tag}"
    if skopeo inspect --no-tags "docker://${PREVIOUS}" >/dev/null 2>&1 &&
        podman run --rm --pull=never --entrypoint /usr/bin/rpm-ostree "localhost/${target_image}:${tag}" \
            compose build-chunked-oci --help | grep -q -- '--previous-build'; then
        PREV_ARGS=(--previous-build "docker://${PREVIOUS}")
    fi

    podman run --rm --pull=never --privileged \
        --mount=type=image,src="${target_image}:${tag}",target=/rpm-ostree \
        --mount=type=bind,src="${GRAPHROOT}",target=/run/host-container-storage,rw \
        --mount=type=tmpfs,target=/run/rpm-ostree-storage \
        --entrypoint /usr/bin/rpm-ostree \
        "localhost/${target_image}:${tag}" \
        compose build-chunked-oci \
        --max-layers 127 \
        --format-version=2 \
        --bootc \
        "${LABEL_ARGS[@]}" \
        "${PREV_ARGS[@]}" \
        --rootfs /rpm-ostree \
        --output "containers-storage:[overlay@/run/host-container-storage+/run/rpm-ostree-storage]localhost/${target_image}:${tag}"

# Generate tags for a build
[group('Utility')]
generate-build-tags $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    DATE=$(date +%Y%m%d)
    TAGS=("${tag}" "${tag}-${DATE}" "${DATE}")
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        TAGS+=("${tag}-${DATE}-${GIT_SHA}")
    fi
    echo "${TAGS[@]}"

# Apply tags to a built image
[group('Utility')]
tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -euox pipefail
    IMAGE=$(podman inspect "${target_image}:${tag}" | jq -r '.[].Id')
    podman untag "${IMAGE}"
    for t in {{ tags }}; do
        podman tag "${IMAGE}" "${target_image}:${t}"
    done
    podman images

# Image name
[group('Utility')]
[private]
image_name:
    @echo "${image_name}"

# Clean build outputs
[group('Utility')]
clean:
    rm -rf output/ _build* versions.env

[private]
sudoif command *args:
    #!/usr/bin/env bash
    if [[ "${UID}" -eq 0 ]]; then
        {{ command }} {{ args }}
    else
        sudo {{ command }} {{ args }}
    fi

# Copy an image from user podman to root podman (bootc-image-builder runs as root)
[private]
_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euox pipefail
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq 0 ]]; then
        exit 0
    fi
    if podman image exists "${target_image}:${tag}"; then
        COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
        just sudoif TMPDIR="${COPYTMP}" podman image scp "${UID}@localhost::${target_image}:${tag}" "root@localhost::${target_image}:${tag}"
        rm -rf "${COPYTMP}"
    else
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a disk image with bootc-image-builder
[private]
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail
    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)
    sudo podman run --rm -it --privileged --pull=newer --net=host \
        --security-opt label=type:unconfined_t \
        -v "$(pwd)/${config}:/config.toml:ro" \
        -v "${BUILDTMP}:/output" \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "${bib_image}" \
        --type "${type}" --use-librepo=True --rootfs=btrfs \
        "${target_image}:${tag}"
    mkdir -p output
    sudo mv -f "${BUILDTMP}"/* output/
    sudo rmdir "${BUILDTMP}"
    sudo chown -R "${USER}:${USER}" output/

# Build a QCOW2 VM image from the local build
[group('Disk images')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build an installer ISO from the local build
[group('Disk images')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "anaconda-iso" "disk_config/iso-gnome.toml")

# Boot the QCOW2 image in a VM (http://localhost:8006)
[group('Disk images')]
run-vm-qcow2:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ -f output/qcow2/disk.qcow2 ]] || just build-qcow2
    port=8006
    while ss -tunalp | grep -q ":${port}"; do port=$((port + 1)); done
    echo "Connect to http://localhost:${port}"
    podman run --rm --privileged --pull=newer \
        --publish "127.0.0.1:${port}:8006" \
        --env CPU_CORES=4 --env RAM_SIZE=8G --env DISK_SIZE=64G --env TPM=Y --env GPU=Y \
        --device=/dev/kvm \
        --volume "${PWD}/output/qcow2/disk.qcow2:/boot.qcow2" \
        docker.io/qemux/qemu

# Run shellcheck on all scripts
[group('Lint')]
lint:
    shellcheck build_files/*.sh

# Run shfmt on all scripts
[group('Lint')]
format:
    shfmt --write build_files/*.sh
