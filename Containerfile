FROM docker.io/library/archlinux:latest

RUN <<EOR

set -euxo pipefail

pacman -Sy

# Some builds (e.g. grub-blscfg w/ gettext) really want some sane locale, so we allow installing them
# sed -i 's/^NoExtract/# NoExtract/g' /etc/pacman.conf

# Development and compilers
pacman -S --noconfirm base base-devel

# GitHub Actions
pacman -S --noconfirm nodejs-lts-jod npm yarn

# Containers
pacman -S --noconfirm podman buildah skopeo fuse-overlayfs

# Utilities
pacman -Sy --noconfirm less git ostree sbsigntools

# Clean up
rm -rf /var/cache/*

# Some package builds like to have a UTF-8 based default locale, so set one up
# echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
# locale-gen
# echo "LANG=en_US.UTF-8" > /etc/locale.conf

mkdir /work
EOR

# ENV LC_ALL=en_US.UTF-8
# ENV LANG=en_US.UTF-8

WORKDIR /work

COPY entrypoint.sh /
COPY build-package.sh /usr/local/bin/
ENTRYPOINT ["/entrypoint.sh"]