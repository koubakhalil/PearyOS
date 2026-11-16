#!/bin/sh
# Joins the PearyOS ISO parts into one file and checks it (macOS / Linux).
set -e
cd "$(dirname "$0")"
echo "Joining the parts into pearyos-1.0-amd64.iso ..."
cat pearyos-1.0-amd64.iso.part-* > pearyos-1.0-amd64.iso
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c pearyos-1.0-amd64.iso.sha256
else
  shasum -a 256 -c pearyos-1.0-amd64.iso.sha256
fi
