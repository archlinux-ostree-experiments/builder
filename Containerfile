FROM docker.io/library/archlinux:latest

RUN <<EOR

set -euxo pipefail

pacman -Sy

# Development and compilers
pacman -S --noconfirm base-devel

# GitHub Actions
pacman -S --noconfirm nodejs-lts-jod npm yarn

# Containers
pacman -S --noconfirm podman buildah skopeo fuse-overlayfs

# Utilities
pacman -S --noconfirm git ostree sbsigntools

EOR
