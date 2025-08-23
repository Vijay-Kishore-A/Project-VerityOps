#!/usr/bin/env bash
set -euo pipefail
IMG="${1:-system_with_hashtree.img}"
VBM="${2:-vbmeta.img}"
OUTDIR="${3:-.}"

python3 avb/avbtool.py info_image --image "$IMG" | tee "$OUTDIR/info_image.txt"
python3 avb/avbtool.py info_image --image "$VBM" | tee "$OUTDIR/info_vbmeta.txt"
