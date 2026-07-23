import QtQuick 2.6

// A blocky pixel rabbit: long ears, grey body, pink nose, cotton tail. Matches the abstract style.
Item {
    id: b
    readonly property real u: b.width / 96
    readonly property real v: b.height / 96
    property color furC: "#c6c0b6"
    property color darkC: "#3c342e"
    property color pinkC: "#d29696"
    Rectangle { x: 30*b.u; y: 6*b.v;  width: 12*b.u; height: 34*b.v; color: b.furC; antialiasing: false }  // ear
    Rectangle { x: 54*b.u; y: 6*b.v;  width: 12*b.u; height: 34*b.v; color: b.furC; antialiasing: false }  // ear
    Rectangle { x: 33*b.u; y: 10*b.v; width: 6*b.u;  height: 24*b.v; color: b.pinkC; antialiasing: false }  // inner ear
    Rectangle { x: 57*b.u; y: 10*b.v; width: 6*b.u;  height: 24*b.v; color: b.pinkC; antialiasing: false }  // inner ear
    Rectangle { x: 24*b.u; y: 34*b.v; width: 48*b.u; height: 50*b.v; color: b.furC; antialiasing: false }  // head/body
    Rectangle { x: 36*b.u; y: 50*b.v; width: 8*b.u;  height: 8*b.v;  color: b.darkC; antialiasing: false }  // eye
    Rectangle { x: 52*b.u; y: 50*b.v; width: 8*b.u;  height: 8*b.v;  color: b.darkC; antialiasing: false }  // eye
    Rectangle { x: 44*b.u; y: 60*b.v; width: 8*b.u;  height: 8*b.v;  color: b.pinkC; antialiasing: false }  // nose
    Rectangle { x: 70*b.u; y: 72*b.v; width: 16*b.u; height: 14*b.v; color: "#ececee"; antialiasing: false } // tail
    Rectangle { x: 28*b.u; y: 84*b.v; width: 14*b.u; height: 12*b.v; color: b.furC; antialiasing: false }  // foot
    Rectangle { x: 54*b.u; y: 84*b.v; width: 14*b.u; height: 12*b.v; color: b.furC; antialiasing: false }  // foot
}
