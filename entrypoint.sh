#!/usr/bin/bash

set -euxo pipefail

ACTION="${1:-build-package}"
TARGET="${2:-.}"
ARTIFACTS="${3:-output}"
INSTALL_DEPS="${4:-true}"
INSTALL_PKG="${5:-true}"
PACKAGER="${6:-GitHub Actions Packager}"

ROOT="$(pwd)"
FULL_ARTIFACTS="$ROOT/$ARTIFACTS"

REPO_ADD_FLAGS="-p"

BUILDER_USER="builder"

create_user() {
    getent passwd "$BUILDER_USER" || useradd -m "$BUILDER_USER"
    echo "${BUILDER_USER} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-allow-builder
    chmod 0440 /etc/sudoers.d/99-allow-builder
}

set +x
GPGSIGN="${7:-}"
KEYID=""
if [ ! "x${GPGSIGN:-}" = "x" ]; then
    # KEYID has not been set, so the key wasn't imported yet
    if [ "x${KEYID}" = "x" ]; then
        create_user
        echo "GPG key specified. Importing..."
        echo "$GPGSIGN" | sudo -u "$BUILDER_USER" gpg --no-tty --import

        # "Trust gpg key via script": https://serverfault.com/questions/1010704/trust-gpg-key-via-script
        KEYID=$(sudo -u "$BUILDER_USER" gpg --no-tty --list-keys | grep -P "\s*[A-F0-9]{32,64}" | tr -d '[:blank:]')
        echo -e "5\ny\n" | sudo -u "$BUILDER_USER" gpg --no-tty --command-fd 0 --edit-key "$KEYID" trust

        REPO_ADD_FLAGS="$REPO_ADD_FLAGS --sign --key $KEYID"
    fi
fi
set -x

prepare() {
    if [ -x ./prepare.sh ]; then
        sudo -u "$BUILDER_USER" ./prepare.sh
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


if [ "x$ACTION" = "xbuild-package" ]; then
    create_user
    mkdir -p "$FULL_ARTIFACTS"
    chown -R "$BUILDER_USER" "$FULL_ARTIFACTS"
    for pkg in $TARGET; do
        chown -R "$BUILDER_USER" "$pkg"
        sudo -u "$BUILDER_USER" build-package.sh "$pkg" "$ARTIFACTS" "$KEYID" "$INSTALL_DEPS" "$INSTALL_PKG" "$PACKAGER"
    done
    exit 0
fi

if [ "x$ACTION" = "xbuild-repo" ]; then
    cd "$TARGET"
    # Sanitize filenames. Otherwise, other systems might mess with them.
    # For example, GH Releases will replace colons with periods, making the db reference invalid.
    for file in *.pkg.tar.zst; do
        mv "$file" $(echo "$file" | sed -e 's/[^A-Za-z0-9._-]/./g')
    done
    sudo -u "$BUILDER_USER" repo-add $REPO_ADD_FLAGS "${ARTIFACTS}.db.tar.zst" *.pkg.tar.zst
    cd "$ROOT"

    exit 0
fi

if [ "x$ACTION" = "xrun-custom" ]; then
    exec $TARGET
fi

exec $@
