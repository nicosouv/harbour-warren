import QtQuick 2.6

// A blocky pixel magpie built from flat rectangles: black body, white belly, blue tail, orange
// beak. Same abstract style as the badger; used for the magpie faction on the map and in icons.
Item {
    id: b
    readonly property real u: b.width / 96
    readonly property real v: b.height / 96
    property color bodyC: "#1f212c"
    property color bellyC: "#e2e5ec"
    property color tailC: "#3c6e96"
    property color beakC: "#e0963c"
    Rectangle { x: 58*b.u; y: 58*b.v; width: 14*b.u; height: 12*b.v; color: b.tailC; antialiasing: false }
    Rectangle { x: 66*b.u; y: 68*b.v; width: 16*b.u; height: 14*b.v; color: b.tailC; antialiasing: false }
    Rectangle { x: 74*b.u; y: 80*b.v; width: 16*b.u; height: 14*b.v; color: b.tailC; antialiasing: false }
    Rectangle { x: 26*b.u; y: 34*b.v; width: 38*b.u; height: 44*b.v; color: b.bodyC; antialiasing: false }
    Rectangle { x: 34*b.u; y: 50*b.v; width: 22*b.u; height: 24*b.v; color: b.bellyC; antialiasing: false }
    Rectangle { x: 40*b.u; y: 14*b.v; width: 32*b.u; height: 32*b.v; color: b.bodyC; antialiasing: false }
    Rectangle { x: 58*b.u; y: 22*b.v; width: 8*b.u;  height: 8*b.v;  color: b.bellyC; antialiasing: false }
    Rectangle { x: 60*b.u; y: 24*b.v; width: 4*b.u;  height: 4*b.v;  color: "#0f0f14"; antialiasing: false }
    Rectangle { x: 72*b.u; y: 26*b.v; width: 18*b.u; height: 10*b.v; color: b.beakC; antialiasing: false }
    Rectangle { x: 38*b.u; y: 78*b.v; width: 8*b.u;  height: 14*b.v; color: b.beakC; antialiasing: false }
    Rectangle { x: 54*b.u; y: 78*b.v; width: 8*b.u;  height: 14*b.v; color: b.beakC; antialiasing: false }
}
