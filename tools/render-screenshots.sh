#!/usr/bin/env bash
# Regenerates docs/screenshots/*.png offscreen (no screen capture involved).
set -euo pipefail
cd "$(dirname "$0")/.."
QML="$(command -v qml6 || command -v qml || echo /usr/lib/qt6/bin/qml)"
mkdir -p docs/screenshots
for s in idle music mic card; do
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl QT_QPA_PLATFORMTHEME=kde \
        "$QML" tools/preview.qml -- "$s" "docs/screenshots/notch-$s.png"
done
