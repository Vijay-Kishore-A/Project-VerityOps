#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-system.img}"
DST="${2:-system_with_hashtree.img}"
KEY="${3:-testkey_rsa2048.pem}"
EXTRA_MB_START="${4:-16}"    # headroom; script auto-tunes if too small

cp -f "$SRC" "$DST"
SIZE=$(stat -c%s "$DST")
EXTRA_MB="$EXTRA_MB_START"

calc_max_for_partsize() {
  local part_size="$1"
  python3 avb/avbtool.py add_hashtree_footer \
    --image "$DST" \
    --partition_name system \
    --partition_size "$part_size" \
    --hash_algorithm sha256 \
    --salt 00 \
    --do_not_generate_fec \
    --calc_max_image_size
}

# Find a partition_size big enough that max_image_size >= current SIZE.
while : ; do
  PART_SIZE=$(( SIZE + EXTRA_MB*1024*1024 ))
  MAX_IMAGE=$(calc_max_for_partsize "$PART_SIZE" || echo 0)
  if [ "$MAX_IMAGE" -ge "$SIZE" ]; then break; fi
  EXTRA_MB=$(( EXTRA_MB * 2 ))
done

# Pad exactly to the expected max data size, then add the real tree.
truncate -s "$MAX_IMAGE" "$DST"
SALT="$(openssl rand -hex 32)"
echo "add_hashtree: size=$SIZE part_size=$PART_SIZE max_image=$MAX_IMAGE extra_mb=$EXTRA_MB salt=$SALT"

python3 avb/avbtool.py add_hashtree_footer \
  --image "$DST" \
  --partition_name system \
  --partition_size "$PART_SIZE" \
  --hash_algorithm sha256 \
  --salt "$SALT" \
  --key "$KEY" \
  --algorithm SHA256_RSA2048 \
  --do_not_generate_fec
