#!/bin/bash
# Step 1: a minimal Ubuntu 24.04 (noble) root filesystem from the official archive.
# Needs root, debootstrap and network access to archive.ubuntu.com.  WORK=<dir> chooses where things are built.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); SRC=$(dirname "$HERE"); WORK=${WORK:-$SRC/work}
ROOT=$WORK/rootfs
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
mkdir -p "$WORK"
if [ -e "$ROOT/etc/os-release" ]; then echo "rootfs already exists at $ROOT (delete it to start over)"; exit 0; fi
debootstrap --variant=minbase --arch=amd64 --components=main,universe noble "$ROOT" http://archive.ubuntu.com/ubuntu
echo "BOOTSTRAP COMPLETE"
