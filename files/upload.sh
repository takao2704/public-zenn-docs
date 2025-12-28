#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/upload.sh [PORT]
# If PORT is omitted, mpremote will auto-detect the board.

PORT="${1-}"
MPREMOTE_BIN="${MPREMOTE_BIN:-mpremote}"

cmd=("$MPREMOTE_BIN")
if [ -n "$PORT" ]; then
    cmd+=(connect "$PORT")
fi

echo "Ensuring /lib exists on the device..."
"${cmd[@]}" mkdir lib >/dev/null 2>&1 || true

read -r -d '' CLEAR_CODE <<'PY' || true
import os, errno
def clear_dir(path):
    try:
        entries = list(os.ilistdir(path))
    except OSError as e:
        if e.args[0] == errno.ENOENT:
            return
        raise
    for entry in entries:
        name, typ = entry[0], entry[1]
        full = path + '/' + name
        if typ & 0x4000:  # directory
            clear_dir(full)
            try:
                os.rmdir(full)
            except OSError:
                pass
        else:
            try:
                os.remove(full)
            except OSError:
                pass
clear_dir('lib')
PY

echo "Clearing device /lib to mirror local lib/ ..."
"${cmd[@]}" exec "$CLEAR_CODE" >/dev/null || echo "Warning: failed to clear /lib (device connected?)" >&2

echo "Uploading .mpy files to device /lib/ ..."

# Upload all .mpy files, preserving directory structure
find lib -name "*.mpy" | while read -r file; do
    # Get the directory path relative to lib/
    dir=$(dirname "$file" | sed 's|^lib||' | sed 's|^/||')

    if [ -n "$dir" ]; then
        echo "  Creating directory: /lib/$dir"
        "${cmd[@]}" mkdir "lib/$dir" >/dev/null 2>&1 || true
        echo "  Uploading: $file -> /lib/$dir/"
        "${cmd[@]}" cp "$file" ":lib/$dir/"
    else
        echo "  Uploading: $file -> /lib/"
        "${cmd[@]}" cp "$file" ":lib/"
    fi
done

echo "Done."
