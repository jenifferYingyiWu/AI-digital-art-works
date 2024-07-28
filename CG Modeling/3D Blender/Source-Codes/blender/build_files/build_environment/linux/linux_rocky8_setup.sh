#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2022-2023 Blender Authors
#
# SPDX-License-Identifier: GPL-2.0-or-later

# This script is part of the official build environment, see wiki page for details.
# https://developer.blender.org/docs/handbook/release_process/build/rocky_8/

set -e

if [ `id -u` -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Required by: config manager command below to enable powertools.
dnf -y install 'dnf-command(config-manager)'

# Packages `ninja-build` and `meson` are not available unless CBR or PowerTools repositories are enabled.
# See: https://wiki.rockylinux.org/rocky/repo/#notes-on-unlisted-repositories
dnf config-manager --set-enabled powertools

# Required by: epel-release has the patchelf and rubygem-asciidoctor packages
dnf -y install epel-release

# `yum-config-manager` does not come in the default minimal install,
# so make sure it is installed and available.
yum -y update
yum -y install yum-utils

# Install all the packages needed for a new tool-chain.
#
# NOTE: Keep this separate from the packages install, since otherwise
# older tool-chain will be installed.
yum -y update
yum -y install scl-utils
yum -y install scl-utils-build

# Currently this is defined by the VFX platform (CY2023), see: https://vfxplatform.com
yum -y install gcc-toolset-11

# Repository for CUDA (`nvcc`).
dnf config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/rhel8/$(uname -i)/cuda-rhel8.repo

# Install packages needed for Blender's dependencies.
PACKAGES_FOR_LIBS=(
    # Used to checkout Blender's code.
    git
    git-lfs
    # Used to extract packages.
    bzip2
    # Used to extract packages.
    tar
    # Blender and some dependencies use `cmake`.
    cmake3
    # Apply patches from Blender's: `./build_files/build_environment/patches`
    patch
    # Use by `cmake` and `autoconf`.
    make

    # Required by: `external_nasm` which uses an `autoconf` build-system.
    autoconf
    automake
    libtool

    # Required by: `external_libsndfile` configure scripts.
    autogen

    # Used to set rpath on shared libraries
    patchelf

    # Builds generated by meson use Ninja for the actual build.
    ninja-build

    # Required by Blender build option: `WITH_GHOST_WAYLAND`.
    mesa-libEGL-devel
    # Required by: Blender & `external_opensubdiv` (probably others).
    mesa-libGL-devel
    mesa-libGLU-devel

    # NOTE(@ideasman42): Currently flex's `autogen.sh` is required to run because the bundled
    # configuration is looking for an older version of `aclocal` than the system provides.
    # This is resolved by generating new configuration files which requires the `autopoint`
    # command from `gettext-devel`, if the flex package is updated we could remove this.
    # Required by: [`flex` running `autogen.sh` for `autopoint`].
    gettext-devel
    # NOTE(@ideasman42): It seems newer files generated by `autogen.sh` also require `makeinfo`
    # and there isn't a flag to disable GNU "info".
    # Required by: [`flex` as a build-time dependency for `makeinfo`].
    texinfo

    # NOTE(@ideasman42): `nvcc` will *not* be added to the `PATH`, must be done manually.
    # Commands from:
    # https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#environment-setup
    # Can be added to `~/.bash_profile`.
    # `export LD_LIBRARY_PATH=/usr/local/cuda-12.5/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}`
    # `export PATH=/usr/local/cuda-12.5/bin${PATH:+:${PATH}}`
    # Required by `external_openimagedenoise` (`nvcc` command)
    cuda-toolkit

    # Required by: `external_ispc`.
    zlib-devel
    # TODO: dependencies build without this, consider removal.
    rubygem-asciidoctor
    # TODO: dependencies build without this, consider removal.
    wget
    # Required by: `external_sqlite` as a build-time dependency (needed for the `tclsh` command).
    tcl
    # Required by: `external_aom`.
    # TODO: Blender is already building `external_nasm` which is listed as an alternative to `yasm`.
    # Why are both needed?
    yasm

    # NOTE(@ideasman42): while `python39` is available, the default Python version is 3.6.
    # This is used for the `python3-mako` package for e.g.
    # So use the "default" system Python since it means it's most compatible with other packages.
    python3
    # Required by: `external_mesa`.
    python3-mako

    # Required by: `external_mesa`.
    expat-devel

    # Required by: `external_mesa`.
    libxshmfence
    libxshmfence-devel

    # Required by: `external_igc` & `external_osl` as a build-time dependency.
    bison
    # Required by: `external_osl` as a build-time dependency.
    flex

    # Required by: `external_ispc`.
    ncurses-devel
    # Required by: `external_ispc` (when building with CLANG).
    libstdc++-static

    # Required by: `external_ssl` (build dependencies).
    perl-IPC-Cmd
    perl-Pod-Html

    # Required by: `external_wayland_weston`
    cairo-devel
    libdrm-devel
    pixman-devel
    libffi-devel
    libinput-devel
    libevdev-devel
    mesa-libEGL-devel
    systemd-devel # for `libudev` (not so obvious!).
    # Required by: `weston --headless` (run-time requirement for off screen rendering).
    mesa-dri-drivers
    mesa-libEGL
    mesa-libGL
)

# Additional packages needed for building Blender.
PACKAGES_FOR_BLENDER=(
    # Required by Blender build option: `WITH_GHOST_WAYLAND`.
    libxkbcommon-devel

    # Required by Blender build option: `WITH_GHOST_X11`.
    libX11-devel
    libXcursor-devel
    libXi-devel
    libXinerama-devel
    libXrandr-devel
    libXt-devel
    libXxf86vm-devel
)

yum -y install -y ${PACKAGES_FOR_LIBS[@]} ${PACKAGES_FOR_BLENDER[@]}

# Dependencies for pip (needed for `buildbot-worker`), uses Python3.6.
yum -y install python3 python3-pip python3-devel

# Dependencies for asound.
yum -y install -y  \
    alsa-lib-devel pulseaudio-libs-devel

# Required by Blender build option: `WITH_JACK`.
yum -y install jack-audio-connection-kit-devel

# AMD's ROCM
# Based on instructions from:
# https://rocm.docs.amd.com/projects/install-on-linux/en/latest/how-to/native-install/rhel.html
# NOTE: the following steps have intentionally been skipped as they aren't needed:
# - "Register kernel-mode driver".
# - "Install kernel driver".

# Register ROCm packages
rm -f /etc/yum.repos.d/rocm.repo
tee --append /etc/yum.repos.d/rocm.repo <<EOF
[ROCm-6.1.2]
name=ROCm6.1.2
baseurl=https://repo.radeon.com/rocm/rhel8/6.1.2/main
enabled=1
priority=50
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOF
yum -y update
yum -y install rocm