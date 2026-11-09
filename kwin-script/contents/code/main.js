// Virtual Notch hover detector.
// The notch overlay ignores the mouse (so tabs underneath stay clickable); this script
// watches the cursor and tells the widget only when the hover *zone* changes:
//   0 = away
//   1 = approaching / on the notch  -> notch slides away so the browser tabs under it show
//   3 = pushed against the top screen edge above the notch -> (after a dwell) opens the card
//   2 = over the expanded card area (keeps it open)
const NOTCH_W = 260, NOTCH_H = 34;
const NEAR_X = 30, NEAR_Y = 14;   // extra margin so it moves away just before you reach it
const EDGE = 1;                   // top-edge hot zone height (px)
const CARD_W = 390, CARD_H = 470;
let level = 0;

function send(v) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
        "var c=panels().concat(desktops());" +
        "for(var i=0;i<c.length;i++){var w=c[i].widgets('io.github.wnibraj.virtualnotch');" +
        "for(var j=0;j<w.length;j++){w[j].currentConfigGroup=['General'];w[j].writeConfig('hover'," + v + ");w[j].reloadConfig();}}");
}

function check() {
    const p = workspace.cursorPos;
    const out = workspace.activeScreen;
    if (!out) return;
    const g = out.geometry;
    const dx = Math.abs(p.x - (g.x + g.width / 2));
    const dy = p.y - g.y;
    let now = 0;
    if (dy >= 0 && dy <= EDGE && dx <= NOTCH_W / 2) now = 3;
    else if ((level === 3 || level === 2) && dy >= 0 && dy <= CARD_H && dx <= CARD_W / 2) now = 2;
    else if (dy >= 0 && dy <= NOTCH_H + NEAR_Y && dx <= NOTCH_W / 2 + NEAR_X) now = 1;
    if (now !== level) { level = now; send(now); }
}

workspace.cursorPosChanged.connect(check);
