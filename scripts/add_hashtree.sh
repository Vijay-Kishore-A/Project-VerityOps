#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-system.img}"                        # input ext4
DST="${2:-system_with_hashtree.img}"         # output image
KEY="${3:-testkey_rsa2048.pem}"              # RSA key (PEM)
EXTRA_MB_START="${4:-8}"                      # headroom MiB

cp -f "$SRC" "$DST"
SIZE=$(stat -c%s "$DST")
EXTRA_MB="$EXTRA_MB_START"

calc_max_for_partsize() {
  local part_size="$1"
  python3 avb/avbtool.py add_hashtree_footer \
    --image "$DST" --partition_name system --partition_size "$part_size" \
    --hash_algorithm sha256 --salt 00 --do_not_generate_fec \
    --calc_max_image_size
}

# 1) Find a partition_size that actually fits this data
tries=0
while : ; do
  PART_SIZE=$(( SIZE + EXTRA_MB*1024*1024 ))
  MAX_IMAGE=$(calc_max_for_partsize "$PART_SIZE" || echo 0)
  if [[ "$MAX_IMAGE" -ge "$SIZE" && "$MAX_IMAGE" -le "$PART_SIZE" ]]; then
    break
  fi
  EXTRA_MB=$(( EXTRA_MB * 2 ))
  tries=$((tries+1))
  if [[ $tries -gt 5 ]]; then
    echo "❌ Could not find a sane partition size for SIZE=$SIZE" >&2
    exit 1
  fi
done

# 2) Pad data region exactly to what avbtool expects
truncate -s "$MAX_IMAGE" "$DST"

# 3) Add real footer for the same PART_SIZE
SALT="$(openssl rand -hex 32)"
echo "add_hashtree: size=$SIZE part_size=$PART_SIZE max_image=$MAX_IMAGE extra_mb=$EXTRA_MB salt=$SALT"
python3 avb/avbtool.py add_hashtree_footer \
  --image "$DST" --partition_name system --partition_size "$PART_SIZE" \
  --hash_algorithm sha256 --salt "$SALT" \
  --key "$KEY" --algorithm SHA256_RSA2048 --do_not_generate_fec

# 4) Sanity: confirm tree lies within file bounds
INFO="$(python3 avb/avbtool.py info_image --image "$DST")"
FILE_SIZE=$(stat -c%s "$DST")
TREE_OFF=$(awk '/Tree offset:/ {print $3}' <<<"$INFO")
TREE_SIZE=$(awk '/Tree size:/ {print $3}' <<<"$INFO")
if [[ -z "$TREE_OFF" || -z "$TREE_SIZE" ]]; then
  echo "❌ Missing tree offsets in descriptor" >&2; exit 1
fi
END=$((TREE_OFF + TREE_SIZE))
if [[ "$END" -gt "$FILE_SIZE" ]]; then
  echo "❌ Descriptor points past end of file (end=$END file=$FILE_SIZE)" >&2
  exit 1
fi
echo "OK: tree_end=$END file_size=$FILE_SIZE"
# Print first 120 lines for logs (helps debug quickly)
sed -n '1,120p' <<<"$INFO"
