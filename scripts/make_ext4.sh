#!/usr/bin/env bash
set -euo pipefail
IMG="${1:-system.img}"       # output file
SIZE_MB="${2:-128}"          # size in MiB
LABEL="${3:-system}"

dd if=/dev/zero of="$IMG" bs=1M count="$SIZE_MB"
mkfs.ext4 -F -L "$LABEL" "$IMG"
stat -c "Created %n (%s bytes)" "$IMG"

