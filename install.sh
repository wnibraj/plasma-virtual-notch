#!/usr/bin/env bash
# Virtual Notch installer for KDE Plasma 6 (Wayland).
# Installs for the current user only (no sudo). Safe to re-run: it updates in place.
set -euo pipefail

ID="io.github.wnibraj.virtualnotch"
KWIN_ID="virtualnotch"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Options:  --city "Name"   show weather for this city on the notch ("" = turn weather off)
CITY=""; CITY_SET=0
while [ $# -gt 0 ]; do
    case "$1" in
        --city)   [ $# -ge 2 ] || { echo "--city needs a value" >&2; exit 1; }; CITY="$2"; CITY_SET=1; shift 2 ;;
        --city=*) CITY="${1#--city=}"; CITY_SET=1; shift ;;
        -h|--help) echo "Usage: ./install.sh [--city \"Your City\"]"; exit 0 ;;
        *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
    esac
done
# keep it safe inside the JS string below
CITY="$(printf '%s' "$CITY" | tr -d "'\\\"\n")"

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m xx\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- checks
for c in kpackagetool6 kwriteconfig6 busctl; do
    command -v "$c" >/dev/null || die "'$c' not found. Virtual Notch needs KDE Plasma 6 (and systemd's busctl)."
done
busctl --user status org.kde.plasmashell >/dev/null 2>&1 \
    || die "Plasma isn't running. Run this from inside your Plasma session (not over SSH/TTY)."
[ "${XDG_SESSION_TYPE:-}" = "wayland" ] \
    || warn "This doesn't look like a Wayland session. The notch overlay only works on Plasma Wayland."

# Required QML modules (package names differ per distro, so we name what provides them)
QML_DIR=""
for q in qtpaths6 qtpaths-qt6 /usr/lib/qt6/bin/qtpaths /usr/lib64/qt6/bin/qtpaths /usr/lib/x86_64-linux-gnu/qt6/bin/qtpaths; do
    if command -v "$q" >/dev/null 2>&1; then QML_DIR="$("$q" --query QT_INSTALL_QML 2>/dev/null || true)"; break; fi
done
if [ -n "$QML_DIR" ] && [ -d "$QML_DIR" ]; then
    missing=0
    check_mod() {
        if [ ! -d "$QML_DIR/$1" ]; then warn "Missing QML module $1 (provided by: $2)"; missing=1; fi
    }
    check_mod org/kde/layershell               "layer-shell-qt"
    check_mod org/kde/ksysguard/sensors        "libksysguard / ksystemstats"
    check_mod org/kde/plasma/private/volume    "plasma-pa"
    check_mod org/kde/plasma/private/mpris     "plasma-workspace"
    check_mod QtQuick/Shapes                   "qt6-declarative"
    check_mod QtQuick/Effects                  "qt6-declarative"
    [ "$missing" = 0 ] || die "Install the packages above with your package manager, then re-run ./install.sh"
else
    warn "Couldn't locate the Qt QML directory; skipping dependency check."
fi

# ---------------------------------------------------------------- install packages
say "Installing the widget"
kpackagetool6 -t Plasma/Applet -u "$HERE/package" >/dev/null 2>&1 \
    || kpackagetool6 -t Plasma/Applet -i "$HERE/package" >/dev/null \
    || die "Could not install the widget package."

say "Installing the KWin hover helper"
kpackagetool6 -t KWin/Script -u "$HERE/kwin-script" >/dev/null 2>&1 \
    || kpackagetool6 -t KWin/Script -i "$HERE/kwin-script" >/dev/null \
    || die "Could not install the KWin script."

kwriteconfig6 --file kwinrc --group Plugins --key "${KWIN_ID}Enabled" true
# reload so an updated script takes effect
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s "$KWIN_ID" >/dev/null 2>&1 || true
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1 || true
sleep 1
if ! busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting isScriptLoaded s "$KWIN_ID" 2>/dev/null | grep -q true; then
    SCRIPT="$(kpackagetool6 -t KWin/Script -s "$KWIN_ID" 2>/dev/null | tail -n1)"
    [ -d "$SCRIPT" ] || SCRIPT="${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/$KWIN_ID"
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript ss "$SCRIPT/contents/code/main.js" "$KWIN_ID" >/dev/null 2>&1 || true
    busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting start >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------- detect sensors
say "Detecting your sensors"
SENSORS="$(busctl --user call org.kde.ksystemstats1 /org/kde/ksystemstats1 org.kde.ksystemstats1 allSensors 2>/dev/null \
           | grep -oE '"[^" ]+"' | tr -d '"' | sort -V || true)"
pick() { printf '%s\n' "$SENSORS" | grep -E "$1" | head -n1 || true; }
GPU="$(pick '^gpu/gpu[0-9]+/temperature$' | sed 's|/temperature$||')"
[ -n "$GPU" ] || GPU="$(pick '^gpu/gpu[0-9]+/usage$' | sed 's|/usage$||')"
BAT="$(pick '^power/[^/]+/chargePercentage$' | sed 's|/chargePercentage$||')"
FAN="$(pick '^lmsensors/[^/]+/fan[0-9]+$')"
SSD="$(pick '^lmsensors/nvme[^/]*/temp[0-9]+$')"
printf '    GPU:     %s\n    Battery: %s\n    Fan:     %s\n    SSD:     %s\n' \
    "${GPU:-none}" "${BAT:-none}" "${FAN:-none}" "${SSD:-none}"
[ -n "$SENSORS" ] || warn "ksystemstats didn't answer. CPU/RAM still work; other rows stay hidden until you re-run this."

# ---------------------------------------------------------------- add to a panel + configure
say "Adding the notch to your desktop"
JS="var id='$ID', ws=[], ps=panels(), ds=desktops();
if (locked) { print('LOCKED'); } else {
  var cs = ps.concat(ds);
  for (var i = 0; i < cs.length; i++) ws = ws.concat(cs[i].widgets(id));
  if (!ws.length) { var host = ps.length ? ps[0] : ds[0]; ws = [host.addWidget(id)]; }
  for (var j = 0; j < ws.length; j++) {
    var w = ws[j]; w.currentConfigGroup = ['General'];
    w.writeConfig('gpuSensor', '$GPU'); w.writeConfig('batterySensor', '$BAT');
    w.writeConfig('fanSensor', '$FAN'); w.writeConfig('ssdSensor', '$SSD');
    if ($CITY_SET) w.writeConfig('weatherCity', '$CITY');
    w.reloadConfig();
  }
  print('OK ' + ws.length);
}"
OUT="$(busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$JS" 2>&1 || true)"
case "$OUT" in
    *LOCKED*) die "Your widgets are locked. Unlock them (right-click desktop → Unlock Widgets) and re-run." ;;
    *OK*)     ;;
    *)        die "Couldn't add the widget: $OUT" ;;
esac

say "Done! The notch is at the top-center of your screen."
if [ "$CITY_SET" = 1 ] && [ -n "$CITY" ]; then echo "    • Weather on the notch: $CITY"
elif [ "$CITY_SET" = 0 ]; then echo "    • Tip: show weather on the notch with  ./install.sh --city \"Your City\""; fi
echo "    • Mouse near it        → it slides away so whatever is under it (e.g. browser tabs) is visible"
echo "    • Push mouse to the top edge above it and hold ~½ s → stats card"
echo "    • Uninstall any time:  ./uninstall.sh"
