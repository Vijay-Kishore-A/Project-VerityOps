#!/usr/bin/env bash
set -euo pipefail
IMG="${1:-system_with_hashtree.img}"     # clean augmented image
VBM="${2:-vbmeta.img}"                   # clean vbmeta
KEY="${3:-testkey_rsa2048.pem}"          # key used for vbmeta
SEEK="${4:-100}"                         # 4KiB block index to flip
COUNT="${5:-1}"                          # number of blocks to flip

cp -f "$IMG" system_tampered.img
dd if=/dev/urandom of=system_tampered.img bs=4096 count="$COUNT" seek="$SEEK" conv=notrunc

python3 avb/avbtool.py make_vbmeta_image \
  --include_descriptors_from_image system_tampered.img \
  --key "$KEY" \
  --algorithm SHA256_RSA2048 \
  --output vbmeta_tampered.img

python3 avb/avbtool.py calculate_vbmeta_digest --image "$VBM" --hash_algorithm sha256 | tee digest_clean.txt
python3 avb/avbtool.py calculate_vbmeta_digest --image vbmeta_tampered.img --hash_algorithm sha256 | tee digest_tampered.txt

if diff -q digest_clean.txt digest_tampered.txt >/dev/null; then
  echo "Tamper NOT detected"; exit 1
else
  echo "Tamper detected (vbmeta digest changed)"; fi
