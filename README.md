# Project-VerityOps

A DevSecOps pipeline for Android-style system images that enforces integrity end-to-end using Android Verified Boot (AVB) and dm-verity. Built an ext4 system.img, append a Merkle hashtree footer, sign metadata into vbmeta.img, and then prove tamper detection by flipping on-disk blocks in CI. Security gates (SAST/SBOM/CVE) and provenance are baked in.
