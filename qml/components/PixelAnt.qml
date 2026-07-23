import QtQuick 2.6

// A blocky pixel ant: three body segments, six legs, two antennae. Rendered small on the map.
Item {
    id: b
    readonly property real u: b.width / 96
    readonly property real v: b.height / 96
    property color bodyC: "#7a3628"
    property color darkC: "#301a14"
    Rectangle { x: 10*b.u; y: 42*b.v; width: 28*b.u; height: 28*b.v; color: b.bodyC; antialiasing: false }  // abdomen
    Rectangle { x: 40*b.u; y: 46*b.v; width: 16*b.u; height: 18*b.v; color: b.darkC; antialiasing: false }   // thorax
    Rectangle { x: 58*b.u; y: 40*b.v; width: 24*b.u; height: 24*b.v; color: b.bodyC; antialiasing: false }   // head
    Rectangle { x: 64*b.u; y: 46*b.v; width: 8*b.u;  height: 8*b.v;  color: "#140f0c"; antialiasing: false }  // eye
    // legs
    Repeater {
        model: [40, 48, 54]
        Item {
            Rectangle { x: (modelData-2)*b.u; y: 62*b.v; width: 4*b.u; height: 22*b.v; color: b.darkC; antialiasing: false }
            Rectangle { x: (modelData-11)*b.u; y: 80*b.v; width: 10*b.u; height: 4*b.v; color: b.darkC; antialiasing: false }
            Rectangle { x: (modelData+2)*b.u;  y: 80*b.v; width: 10*b.u; height: 4*b.v; color: b.darkC; antialiasing: false }
        }
    }
    // antennae
    Rectangle { x: 72*b.u; y: 30*b.v; width: 4*b.u; height: 12*b.v; color: b.darkC; antialiasing: false }
    Rectangle { x: 76*b.u; y: 30*b.v; width: 10*b.u; height: 4*b.v; color: b.darkC; antialiasing: false }
}
