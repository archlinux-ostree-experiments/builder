#!/usr/bin/bash

set -euxo pipefail

TARGET="${1:-.}"
ARTIFACTS="${2:-output}"
GPGSIGN="${3:-}"

ROOT="$(pwd)"
FULL_ARTIFACTS="$ROOT/$ARTIFACTS"

MAKEPKG_FLAGS="-c -C -f"

prepare() {
    if [ -x ./prepare.sh ]; then
        ./prepare.sh
    fi
}

cleanup() {
    if [ -d pkg ]; then
        rm -rf pkg
    fi

    if [ -d src ]; then
        rm -rf src
    fi
}

install_deps() {
    if [ -f PKGBUILD ]; then
        INSTALL_PKG=""
        for pkg in $(makepkg --printsrcinfo | grep -E '\s+depends|\s+makedepends' | sed 's/\s\+\(make\)\?depends = //g' || true); do
            INSTALL_PKG="$INSTALL_PKG $pkg"
        done
        sudo pacman -Sy
        sudo pacman -S --noconfirm $INSTALL_PKG
    fi
}

add_keys() {
    KEYS=$(makepkg --printsrcinfo | grep -E '\s+validpgpkeys' | sed 's/\s\+validpgpkeys = //g' || true)
    if [ ! "z$KEYS" = "z" ]; then
        for key in $KEYS; do
            gpg --recv-key "$key"
        done
    fi
}

prepare_signing() {
    if [ ! "x${GPGSIGN:-}" = "x" ]; then
        MAKEPKG_FLAGS="$MAKEPKG_FLAGS --sign --key $GPGSIGN"
    fi
}

build_package() {
    PKG=${1:-$TARGET}
    cd "$PKG"
    install_deps
    add_keys
    cleanup
    prepare
    prepare_signing
    # The PKGBUILD of `grub` will call git log which opens a pager
    # We don't want to require interactivity, so we set `GIT_PAGER` to `cat`.
    GIT_PAGER=cat makepkg $MAKEPKG_FLAGS
    mv -v *.pkg.tar.* "$FULL_ARTIFACTS"
    cd "$ROOT"
}

build_package "$TARGET"
