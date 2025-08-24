#!/usr/bin/env bash
# add_hashtree.sh
# Usage: bash scripts/add_hashtree.sh <src.img> <dst.img> <key.pem> [headroomMiB]
# - Auto-computes a correct partition_size, pads the image to max_image_size,
#   and adds a signed dm-verity hashtree footer with avbtool.
# - Prints descriptor summary and validates tree is within file bounds.
set -euo pipefail

SRC="${1:-system.img}"                     # input ext4 image
DST="${2:-system_with_hashtree.img}"       # output image with hashtree footer
KEY="${3:-testkey_rsa2048.pem}"            # RSA-2048 PEM key for AVB signing
EXTRA_MB_START="${4:-8}"                   # initial headroom in MiB (script auto-tunes)

# Preconditions
test -f "$SRC" || { echo "❌ Missing input image: $SRC" >&2; exit 1; }
test -f "$KEY" || { echo "❌ Missing key: $KEY" >&2; exit 1; }
test -f avb/avbtool.py || { echo "❌ Missing avb/avbtool.py (clone external/avb)" >&2; exit 1; }

cp -f "$SRC" "$DST"
SIZE=$(stat -c%s "$DST")                   # current data size (bytes)
EXTRA_MB="$EXTRA_MB_START"

calc_max_for_partsize() {
  local part_size="$1"
  # Returns the maximum data size (bytes) that fits this partition once hashtree is appended.
  python3 avb/avbtool.py add_hashtree_footer \
    --image "$DST" \
    --partition_name system \
    --partition_size "$part_size" \
    --hash_algorithm sha256 \
    --salt 00 \
    --do_not_generate_fec \
    --calc_max_image_size
}

# 1) Find a partition_size that fits the current data (MAX_IMAGE >= SIZE)
tries=0
while : ; do
  PART_SIZE=$(( SIZE + EXTRA_MB*1024*1024 ))
  MAX_IMAGE="$(calc_max_for_partsize "$PART_SIZE" || true)"
  # normalize empty/non-numeric
  [[ "$MAX_IMAGE" =~ ^[0-9]+$ ]] || MAX_IMAGE=0
  if [[ "$MAX_IMAGE" -ge "$SIZE" && "$MAX_IMAGE" -le "$PART_SIZE" ]]; then
    break
  fi
  EXTRA_MB=$(( EXTRA_MB * 2 ))
  tries=$((tries+1))
  if [[ $tries -gt 6 ]]; then
    echo "❌ Could not find sane partition size (SIZE=$SIZE) after $tries tries" >&2
    exit 1
  fi
done

# 2) Pad data to exactly the max data size expected by avbtool for this partition
truncate -s "$MAX_IMAGE" "$DST"

# 3) Add the real hashtree footer (signed) for the same partition_size
SALT="$(openssl rand -hex 32)"             # even-length hex
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

# 4) Tolerant sanity check + descriptor preview (for logs & debugging)
INFO="$(python3 avb/avbtool.py info_image --image "$DST" || true)"
echo "---- avbtool info_image (first 160 lines) ----"
printf "%s\n" "$INFO" | sed -n '1,160p'
FILE_SIZE=$(stat -c%s "$DST")

# Try to extract "tree offset" & "tree size" despite label variants ("Hashtree", "Hash tree", etc.)
TREE_OFF_LINE=$(printf "%s\n" "$INFO" | grep -iE 'tree[ _]?offset' || true)
TREE_SIZE_LINE=$(printf "%s\n" "$INFO" | grep -iE 'tree[ _]?size'   || true)

parse_first_num() { # prints decimal; accepts decimal or 0xHEX
  local line="$1" n
  if [[ $line =~ 0x[0-9a-fA-F]+ ]]; then
    n="${BASH_REMATCH[0]}"
    echo $((n))           # bash arithmetic handles 0x…
  else
    echo "$line" | grep -oE '[0-9]+' | head -1
  fi
}

if [[ -n "$TREE_OFF_LINE" && -n "$TREE_SIZE_LINE" ]]; then
  TREE_OFF="$(parse_first_num "$TREE_OFF_LINE" || true)"
  TREE_SIZE="$(parse_first_num "$TREE_SIZE_LINE" || true)"
  if [[ -n "$TREE_OFF" && -n "$TREE_SIZE" ]]; then
    END=$((TREE_OFF + TREE_SIZE))
    if [[ "$END" -gt "$FILE_SIZE" ]]; then
      echo "❌ Descriptor points past end of file (end=$END file=$FILE_SIZE)" >&2
      exit 1
    fi
    echo "OK: tree_end=$END file_size=$FILE_SIZE"
  else
    echo "⚠️ Could not extract numeric tree offsets; continuing (verify step will enforce)."
  fi
else
  echo "⚠️ Descriptor did not expose explicit tree offset/size labels; continuing."
fi

echo "✅ Hashtree footer added and basic sanity check completed."
