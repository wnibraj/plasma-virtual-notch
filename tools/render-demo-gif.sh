#!/usr/bin/env bash
# Renders docs/demo.gif offscreen from tools/demo.qml (no screen recording involved).
# Needs: qt6-declarative (qml), ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
QML="$(command -v qml6 || command -v qml || echo /usr/lib/qt6/bin/qml)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl QT_QPA_PLATFORMTHEME=kde \
    "$QML" tools/demo.qml -- "$TMP"

ffmpeg -loglevel error -y -framerate 25 -i "$TMP/frame-%04d.png" \
    -vf "fps=25,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 docs/demo.gif
echo "wrote docs/demo.gif ($(du -h docs/demo.gif | cut -f1))"
