# goldenblue: Bazzite GNOME + system-layer AI tooling for AMD.
# Build with `just build` (resolves versions.env and pins the base by digest).
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome:stable
ARG LLAMA_IMAGE=ghcr.io/tduarte/goldenblue-llamacpp:latest

# llama.cpp, prebuilt against Fedora's ROCm by Containerfile.llama
FROM ${LLAMA_IMAGE} AS llama

FROM scratch AS ctx
COPY build_files /
COPY versions.env /versions.env
COPY system_files /system_files

FROM ${BASE_IMAGE}

COPY --from=llama /usr/lib/llama.cpp /usr/lib/llama.cpp

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
