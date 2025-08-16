FROM docker.io/library/archlinux:latest AS aurbuilder

RUN <<EOR
set -euxo pipefail

pacman -Sy

pacman -S --noconfirm base-devel git sudo
useradd -m builder
EOR

RUN --mount=type=cache,id=pkg,target=/pkg <<EOR
set -euxo pipefail

pacman --noconfirm -S cargo

# Install paru as an AUR helper
mkdir /build
cd /build
git clone https://aur.archlinux.org/paru.git
chown -R builder paru
pushd paru
sudo -u builder makepkg
rm -rf /pkg/paru*
mv *.pkg.tar.zst /pkg
popd
rm -rf paru
EOR

RUN --mount=type=cache,id=pkg,target=/pkg <<EOR
set -euxo pipefail

# Install gettext 0.25.1-1, because grub won't build with gettext>=0.26
# (cf. https://gitlab.archlinux.org/archlinux/packaging/packages/grub/-/issues/13)

pacman --noconfirm -S emacs

cd /build
git clone -b 0.25.1-1 https://gitlab.archlinux.org/archlinux/packaging/packages/gettext.git
chown -R builder gettext
pushd gettext
sudo -u builder gpg --recv-keys B6301D9E1BBEAC08
sudo -u builder makepkg
rm -rf /pkg/gettext*
mv *.pkg.tar.zst /pkg
popd
rm -rf gettext

sha256sum /pkg/*.pkg.tar.zst > created
EOR

FROM docker.io/library/archlinux:latest

# Reference previous image such that `podman build` will not skip building paru
COPY --from=aurbuilder /build/created /created

# Install useful packages for running as a GH Action
RUN --mount=type=cache,id=pkg,target=/pkg <<EOR
set -euxo pipefail

rm /created

pacman -Sy

pacman -S --noconfirm \
    base base-devel sudo \
    nodejs-lts-jod npm yarn \
    podman buildah skopeo fuse-overlayfs \
    less git ostree sbsigntools

pacman --noconfirm -U /pkg/*.pkg.tar.zst

# Add builder user with sudo permissions
useradd -m builder
echo "builder ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-allow-builder

# Clean up
rm -rf /var/cache/*

mkdir /work
chown -R builder /work
EOR

WORKDIR /work
USER builder

COPY entrypoint.sh /
COPY build-package.sh /usr/local/bin/
ENTRYPOINT ["/entrypoint.sh"]