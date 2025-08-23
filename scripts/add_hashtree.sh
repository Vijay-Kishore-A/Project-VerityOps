#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-system.img}"                       # input image
DST="${2:-system_with_hashtree.img}"        # output image
KEY="${3:-testkey_rsa2048.pem}"             # RSA key (PEM)
EXTRA_MB="${4:-64}"                          # headroom for footer/tree

cp -f "$SRC" "$DST"

SIZE=$(stat -c%s "$DST")
EXTRA=$((EXTRA_MB*1024*1024))
PART_SIZE=$(( ( (SIZE + EXTRA + 4095) / 4096 ) * 4096 ))

SALT="$(openssl rand -hex 32)"               # even-length, newline-free
echo "Using salt=$SALT  partition_size=$PART_SIZE"

python3 avb/avbtool.py add_hashtree_footer \
  --image "$DST" \
  --partition_name system \
  --partition_size "$PART_SIZE" \
  --hash_algorithm sha256 \
  --salt "$SALT" \
  --key "$KEY" \
  --algorithm SHA256_RSA2048 \
  --do_not_generate_fec
