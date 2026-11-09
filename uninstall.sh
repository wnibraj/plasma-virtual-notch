#!/usr/bin/env bash
# Removes Virtual Notch (widget + KWin helper) for the current user.
set -uo pipefail

ID="io.github.wnibraj.virtualnotch"
KWIN_ID="virtualnotch"
say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }

say "Removing the notch from your panels"
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s \
  "var cs=panels().concat(desktops());for(var i=0;i<cs.length;i++){var w=cs[i].widgets('$ID');for(var j=0;j<w.length;j++)w[j].remove();}" \
  >/dev/null 2>&1

say "Stopping the KWin hover helper"
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s "$KWIN_ID" >/dev/null 2>&1
kwriteconfig6 --file kwinrc --group Plugins --key "${KWIN_ID}Enabled" --delete 2>/dev/null
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure >/dev/null 2>&1

say "Uninstalling packages"
kpackagetool6 -t Plasma/Applet -r "$ID" >/dev/null 2>&1
kpackagetool6 -t KWin/Script -r "$KWIN_ID" >/dev/null 2>&1

say "Virtual Notch removed."
