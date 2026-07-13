#!/usr/bin/env bash
#
# restore-dl-splits.sh — reassemble split buildroot download-cache tarballs.
#
# Some prebuilt download tarballs under buildroot/dl exceed GitHub's 100MB
# per-file limit and are stored as byte-exact split volumes:
#
#     <name>.part-00, <name>.part-01, ...   (raw split, 80MB each)
#     <name>.sha256                          (sha256 + filename of the original)
#
# This script walks buildroot/dl, finds every <name>.sha256 marker, cats the
# matching .part-* volumes back into <name>, and verifies the sha256 so
# buildroot's own hash check will pass. Re-running is safe (idempotent):
# an already-correct file is skipped.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DL_DIR="${1:-$SCRIPT_DIR/../buildroot/dl}"

if [ ! -d "$DL_DIR" ]; then
	echo "error: dl dir not found: $DL_DIR" >&2
	exit 1
fi

restored=0
skipped=0

while IFS= read -r -d '' marker; do
	dir="$(dirname "$marker")"
	# marker content: "<sha256>  <original-filename>"
	read -r want name < "$marker"
	target="$dir/$name"

	# Already present and correct -> skip.
	if [ -f "$target" ]; then
		have="$(sha256sum "$target" | awk '{print $1}')"
		if [ "$have" = "$want" ]; then
			skipped=$((skipped + 1))
			continue
		fi
	fi

	# Need the split volumes.
	if ! ls "$target".part-* >/dev/null 2>&1; then
		echo "error: no .part-* volumes for $target" >&2
		exit 1
	fi

	echo "restoring: $target"
	cat "$(dirname "$target")/$name".part-* > "$target"

	have="$(sha256sum "$target" | awk '{print $1}')"
	if [ "$have" != "$want" ]; then
		echo "error: sha256 mismatch after reassembly: $target" >&2
		echo "  want $want" >&2
		echo "  have $have" >&2
		exit 1
	fi
	restored=$((restored + 1))
done < <(find "$DL_DIR" -name '*.sha256' -print0)

echo "dl restore done: $restored restored, $skipped already ok"
