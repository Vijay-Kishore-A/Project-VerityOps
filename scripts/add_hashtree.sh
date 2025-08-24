#!/usr/bin/env bash
set -euo pipefail
SRC="${1:-system.img}"                       # input image
DST="${2:-system_with_hashtree.img}"        # output image
KEY="${3:-testkey_rsa2048.pem}"             # RSA key (PEM)
EXTRA_MB="${4:-8}"                           # headroom in MiB for tree

cp -f "$SRC" "$DST"

SIZE=$(stat -c%s "$DST")
EXTRA=$((EXTRA_MB*1024*1024))
PART_SIZE=$((SIZE + EXTRA))                  # provisional partition size

# Compute the maximum data image size that fits in PART_SIZE once the tree is added.
# We pass a dummy salt; this call only returns a number.
MAX_IMAGE=$(python3 avb/avbtool.py add_hashtree_footer \
  --image "$DST" \
  --partition_name system \
  --partition_size "$PART_SIZE" \
  --hash_algorithm sha256 \
  --salt 00 \
  --do_not_generate_fec \
  --calc_max_image_size)

# Pad the destination image to exactly the max data size expected for this partition.
truncate -s "$MAX_IMAGE" "$DST"

# Now generate the real footer with a proper random salt. Tree will be appended
# so that (data + tree) == PART_SIZE and offsets in the descriptor are correct.
SALT="$(openssl rand -hex 32)"               # clean, even-length hex
echo "Using partition_size=$PART_SIZE max_image=$MAX_IMAGE salt=$SALT"

python3 avb/avbtool.py add_hashtree_footer \
  --image "$DST" \
  --partition_name system \
  --partition_size "$PART_SIZE" \
  --hash_algorithm sha256 \
  --salt "$SALT" \
  --key "$KEY" \
  --algorithm SHA256_RSA2048 \
  --do_not_generate_fec
