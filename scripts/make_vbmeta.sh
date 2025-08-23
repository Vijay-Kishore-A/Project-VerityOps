#!/usr/bin/env bash
set -euo pipefail
IMG="${1:-system_with_hashtree.img}"        # image to scan for descriptors
KEY="${2:-testkey_rsa2048.pem}"             # RSA key
OUT="${3:-vbmeta.img}"                      # vbmeta output

python3 avb/avbtool.py make_vbmeta_image \
  --include_descriptors_from_image "$IMG" \
  --key "$KEY" \
  --algorithm SHA256_RSA2048 \
  --output "$OUT"

stat -c "Wrote %n (%s bytes)" "$OUT"
