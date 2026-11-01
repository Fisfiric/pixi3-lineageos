#!/bin/bash
# Prepare an Ubuntu 18.04 build host (native, VM or WSL2) for LineageOS 14.1 and TWRP.
# 14.1 needs OpenJDK 8, python2 and the 18.04-era toolchain; newer Ubuntu releases do not work without more effort.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
    bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf \
    imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5-dev \
    libsdl1.2-dev libssl-dev libwxgtk3.0-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
    squashfs-tools xsltproc zip zlib1g-dev openjdk-8-jdk python python-pip python3 unzip xz-utils \
    cpio file bsdmainutils libelf-dev u-boot-tools device-tree-compiler \
    android-tools-adb android-tools-fastboot \
    gcc-arm-linux-gnueabi

if ! command -v repo >/dev/null; then
    sudo curl -fsSL -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
    sudo chmod a+x /usr/local/bin/repo
fi

git lfs install

# Jack, the Java compiler server used by 14.1, still talks TLS 1.0/1.1 to itself, which current
# OpenJDK 8 builds disable ("SSL error" during the build). Re-allow them; the original is kept as .orig.
f=/etc/java-8-openjdk/security/java.security
sudo cp -n "$f" "$f.orig"
sudo sed -i -e 's/^\(jdk\.tls\.disabledAlgorithms=SSLv3\), TLSv1, TLSv1\.1,/\1,/' -e 's/ 3DES_EDE_CBC,//' "$f"

git config --global user.name  >/dev/null || echo "NOTE: set git user.name / user.email (repo needs them): git config --global user.name 'You'"
echo "Host ready."
