/*
 * Virtual Notch — a MacBook-style notch / Dynamic Island for Plasma 6 (Wayland).
 *
 * - Drawn in its own click-through layer-shell overlay: no panel, no border, never blocks the
 *   browser tabs or anything else underneath it.
 * - Collapsed: clock · camera lens · equalizer (music playing) or weather (icon + temp; CPU temp if no city set).
 *   Mic in use → orange pulsing mic + app name + glow (event-driven, no polling).
 * - Mouse near it → slides away (browser tabs show). Mouse pushed to the top edge above it
 *   (dwell ~0.6 s) → morphs into a stats card. Hover detection comes from the small
 *   "virtualnotch" KWin script (the overlay itself ignores the mouse), via Plasmoid config "hover".
 * - Sensors are only subscribed while the card is open (CPU temp: every 5 s for the notch).
 *
 * This applet lives invisibly (0 px) in a panel; it only hosts the overlay window.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.plasma.private.volume as Vol
import org.kde.plasma.private.mpris as Mpris
import org.kde.layershell as LayerShell

PlasmoidItem {
    id: root

    // ---------- palette ----------
    readonly property color cBg: "#000000"
    readonly property color cText: "#e0d4ff"
    readonly property color cDim: "#6c6c80"
    readonly property color cAccent: "#c77dff"
    readonly property color cPink: "#ff8fd8"
    readonly property color cCyan: "#5cf2ff"
    readonly property color cMic: "#ff9f43"
    readonly property color cGood: "#5cffa0"
    readonly property color cWarn: "#ffd75c"
    readonly property color cHot: "#ff5c8a"
    readonly property string monoFont: Kirigami.Theme.fixedWidthFont.family   // your system monospace font

    // ---------- geometry ----------
    readonly property int notchW: 250
    readonly property int notchH: 32
    readonly property int cardW: 380
    readonly property int fillet: 10          // concave "shoulders" where the notch meets the top edge

    // ---------- state ----------
    property var micApps: []
    readonly property bool micActive: micApps.length > 0
    readonly property int hoverLevel: Plasmoid.configuration.hover
    property bool open: false
    readonly property bool wantStats: open

    // media (MPRIS)
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string trackTitle: player ? (player.track || "") : ""
    readonly property string trackArtist: player ? (player.artist || "") : ""

    // ---------- hosting applet: invisible in the panel ----------
    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    compactRepresentation: Item {
        Layout.minimumWidth: 0; Layout.preferredWidth: 0; Layout.maximumWidth: 0
        Layout.minimumHeight: 0; Layout.preferredHeight: 0
    }
    fullRepresentation: Item {}
    toolTipMainText: ""
    toolTipSubText: ""

    // ---------- hover logic (levels from the KWin script) ----------
    // 1 = mouse near the notch -> get out of the way; 3 = top edge -> open stats after a dwell
    readonly property bool hidden: hoverLevel === 1 && !open
    Timer { id: dwell; interval: 600; onTriggered: if (root.hoverLevel === 3) root.open = true }
    onHoverLevelChanged: {
        if (hoverLevel === 3) { if (!open) dwell.restart(); }
        else if (hoverLevel === 1) { dwell.stop(); open = false; }
        else if (hoverLevel === 2) { dwell.stop(); }          // keep card open while over it, never open from here
        else { dwell.stop(); open = false; }
    }

    // ---------- microphone detection ----------
    readonly property var ignoreRe: /easyeffects|pulseeffects|cava|pavucontrol|plasma|kmix|speech-dispatcher|xdg-desktop-portal/i
    Instantiator {
        id: sourceInst
        model: Vol.SourceModel {}
        delegate: QtObject { readonly property var obj: model.PulseObject }
        onObjectAdded: Qt.callLater(root.recompute)
        onObjectRemoved: Qt.callLater(root.recompute)
    }
    Instantiator {
        id: outInst
        model: Vol.SourceOutputModel {}
        delegate: QtObject {
            readonly property var obj: model.PulseObject
            readonly property bool corked: obj ? obj.corked : true
            readonly property int dev: obj ? obj.deviceIndex : -1
            onCorkedChanged: Qt.callLater(root.recompute)
            onDevChanged: Qt.callLater(root.recompute)
        }
        onObjectAdded: Qt.callLater(root.recompute)
        onObjectRemoved: Qt.callLater(root.recompute)
    }
    function appName(o) {
        const p = o.properties || {};
        return (o.client && o.client.name) || p["application.name"] || p["node.name"] || o.name || "App";
    }
    function recompute() {
        const monitors = {};
        for (let i = 0; i < sourceInst.count; i++) {
            const s = sourceInst.objectAt(i);
            if (s && s.obj && String(s.obj.name).endsWith(".monitor")) monitors[s.obj.index] = true;
        }
        const apps = [];
        for (let i = 0; i < outInst.count; i++) {
            const d = outInst.objectAt(i);
            if (!d || !d.obj) continue;
            const o = d.obj;
            if (o.virtualStream || o.corked || monitors[o.deviceIndex]) continue;
            const p = o.properties || {};
            const n = appName(o);
            if (ignoreRe.test(n) || ignoreRe.test(p["application.process.binary"] || "")) continue;
            if (apps.indexOf(n) < 0) apps.push(n);
        }
        if (apps.join("|") !== micApps.join("|")) console.info("virtual-notch mic:", apps.length ? apps.join(", ") : "off");
        micApps = apps;
    }

    // ---------- sensors ----------
    // machine-specific IDs come from the config (filled in by install.sh); empty -> that row is hidden
    readonly property string gpuBase: Plasmoid.configuration.gpuSensor || ""
    readonly property string batBase: Plasmoid.configuration.batterySensor || ""
    readonly property bool hasGpu: gpuBase !== ""
    readonly property bool hasBattery: batBase !== ""
    readonly property string fanId: Plasmoid.configuration.fanSensor || ""
    readonly property string ssdId: Plasmoid.configuration.ssdSensor || ""
    readonly property bool hasFan: fanId !== ""
    readonly property bool hasSsd: ssdId !== ""
    Sensors.Sensor { id: cpuTemp;  sensorId: "cpu/all/averageTemperature"; updateRateLimit: root.open ? 1500 : 5000 }
    Sensors.Sensor { id: cpuUse;   sensorId: "cpu/all/usage"; updateRateLimit: 1500; enabled: root.wantStats }
    Sensors.Sensor { id: gpuTemp;  sensorId: root.gpuBase ? root.gpuBase + "/temperature" : ""; updateRateLimit: 1500; enabled: root.wantStats && root.hasGpu }
    Sensors.Sensor { id: gpuUse;   sensorId: root.gpuBase ? root.gpuBase + "/usage" : ""; updateRateLimit: 1500; enabled: root.wantStats && root.hasGpu }
    Sensors.Sensor { id: ramUsed;  sensorId: "memory/physical/used"; updateRateLimit: 1500; enabled: root.wantStats }
    Sensors.Sensor { id: ramPct;   sensorId: "memory/physical/usedPercent"; updateRateLimit: 1500; enabled: root.wantStats }
    Sensors.Sensor { id: batPct;   sensorId: root.batBase ? root.batBase + "/chargePercentage" : ""; updateRateLimit: 1500; enabled: root.wantStats && root.hasBattery }
    Sensors.Sensor { id: batRate;  sensorId: root.batBase ? root.batBase + "/chargeRate" : ""; updateRateLimit: 1500; enabled: root.wantStats && root.hasBattery }
    Sensors.Sensor { id: fan;      sensorId: root.fanId; updateRateLimit: 1500; enabled: root.wantStats && root.hasFan }
    Sensors.Sensor { id: ssdTemp;  sensorId: root.ssdId; updateRateLimit: 1500; enabled: root.wantStats && root.hasSsd }
    Sensors.Sensor { id: uptime;   sensorId: "os/system/uptime"; updateRateLimit: 1500; enabled: root.wantStats }

    function num(s) { const v = Number(s.value); return isNaN(v) ? 0 : v; }
    readonly property real v_cpuTemp: num(cpuTemp)
    readonly property real v_cpuUse: num(cpuUse)
    readonly property real v_gpuTemp: num(gpuTemp)
    readonly property real v_gpuUse: num(gpuUse)
    readonly property real v_ramUsed: num(ramUsed)
    readonly property real v_ramPct: num(ramPct)
    readonly property real v_batPct: num(batPct)
    readonly property real v_batRate: num(batRate)
    readonly property real v_fan: num(fan)
    readonly property real v_ssdTemp: num(ssdTemp)
    readonly property real v_uptime: num(uptime)
    // ---------- weather (Open-Meteo: free, no API key) ----------
    // City from config ("weatherCity"); empty -> notch shows CPU temperature instead.
    readonly property string weatherCity: Plasmoid.configuration.weatherCity || ""
    property real wLat: NaN
    property real wLon: NaN
    property real weatherTemp: NaN
    property int weatherCode: -1
    property bool weatherDay: true
    readonly property bool weatherOk: weatherCity !== "" && !isNaN(weatherTemp)
    readonly property string weatherIcon: weatherIconFor(weatherCode, weatherDay)
    function weatherIconFor(c, day) {
        if (c < 0) return "";
        if (c === 0) return day ? "weather-clear" : "weather-clear-night";
        if (c === 1 || c === 2) return day ? "weather-few-clouds" : "weather-few-clouds-night";
        if (c === 3) return "weather-overcast";
        if (c === 45 || c === 48) return "weather-fog";
        if ((c >= 51 && c <= 57) || c === 61 || c === 80) return "weather-showers-scattered";
        if ((c >= 62 && c <= 67) || c === 81 || c === 82) return "weather-showers";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather-snow";
        if (c >= 95) return "weather-storm";
        return "weather-clouds";
    }
    property bool weatherBusy: false        // one request chain at a time
    function getJson(url, ok) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            weatherBusy = false;
            let data = null;
            if (x.status === 200) { try { data = JSON.parse(x.responseText); } catch (e) {} }
            if (data) ok(data); else weatherRetry.restart();
        };
        x.timeout = 15000;
        x.open("GET", url);
        x.send();
    }
    function refreshWeather() {
        if (weatherCity === "" || weatherBusy) return;
        weatherBusy = true;
        if (isNaN(wLat)) {
            getJson("https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(weatherCity), function (d) {
                if (!d.results || !d.results.length) { console.warn("virtual-notch: city not found:", weatherCity); return; }
                wLat = d.results[0].latitude; wLon = d.results[0].longitude;
                refreshWeather();
            });
            return;
        }
        getJson("https://api.open-meteo.com/v1/forecast?current=temperature_2m,weather_code,is_day&latitude=" + wLat + "&longitude=" + wLon, function (d) {
            if (!d.current) { weatherRetry.restart(); return; }
            weatherTemp = d.current.temperature_2m;
            weatherCode = d.current.weather_code;
            weatherDay = d.current.is_day === 1;
            console.info("virtual-notch weather:", weatherCity, weatherTemp + "°C", "code", weatherCode, "->", weatherIcon);
        });
    }
    onWeatherCityChanged: { wLat = NaN; wLon = NaN; weatherTemp = NaN; weatherCode = -1; Qt.callLater(refreshWeather); }
    Timer {   // every 15 min (Open-Meteo updates current conditions every 15 min)
        interval: 15 * 60 * 1000; repeat: true; triggeredOnStart: true
        running: root.weatherCity !== ""
        onTriggered: Qt.callLater(root.refreshWeather)   // callLater merges this with onWeatherCityChanged at startup
    }
    Timer { id: weatherRetry; interval: 60 * 1000; onTriggered: root.refreshWeather() }   // offline / after resume

    function tempColor(t) { return t >= 80 ? cHot : t >= 62 ? cWarn : cGood; }
    function loadColor(p) { return p >= 85 ? cHot : p >= 60 ? cWarn : cAccent; }

    // =====================================================================
    //  The overlay window (click-through, above normal windows, no border)
    // =====================================================================
    Window {
        id: overlay
        width: root.cardW + 2 * root.fillet + 80
        height: 500
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        visible: true

        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.activateOnShow: false
        LayerShell.Window.scope: "virtual-notch"

        // Self-heal: after suspend/resume or a display change the compositor can drop the
        // layer surface. Re-create it (hide + show) whenever the screen setup changes.
        onScreenChanged: reattach.restart()
        property bool _cycling: false
        onVisibleChanged: if (!visible && !_cycling) reattach.restart()
        Connections {
            target: Qt.application
            function onScreensChanged() { reattach.restart() }
        }
        Timer {
            id: reattach
            interval: 1500
            onTriggered: {
                overlay.screen = Qt.application.screens[0];
                overlay._cycling = true;
                overlay.visible = false;
                overlay.visible = true;
                overlay._cycling = false;
            }
        }

        Island {
            n: root
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
