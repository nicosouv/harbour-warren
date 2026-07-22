import QtQuick 2.6

// A blocky pixel badger built from flat rectangles: a white striped face over a grey body. The
// same look as the village crowd, reused wherever a badger icon is needed (units, headers).
Item {
    id: b
    property color furC: "#7f8590"
    property color darkC: "#2b2e36"
    property color faceC: "#d9dade"
    Rectangle { x: b.width*0.10; y: b.height*0.08; width: b.width*0.20; height: b.height*0.16; color: b.darkC; antialiasing: false }
    Rectangle { x: b.width*0.70; y: b.height*0.08; width: b.width*0.20; height: b.height*0.16; color: b.darkC; antialiasing: false }
    Rectangle { x: b.width*0.18; y: b.height*0.16; width: b.width*0.64; height: b.height*0.40; color: b.faceC; antialiasing: false }
    Rectangle { x: b.width*0.28; y: b.height*0.16; width: b.width*0.12; height: b.height*0.40; color: b.darkC; antialiasing: false }
    Rectangle { x: b.width*0.60; y: b.height*0.16; width: b.width*0.12; height: b.height*0.40; color: b.darkC; antialiasing: false }
    Rectangle { x: b.width*0.44; y: b.height*0.44; width: b.width*0.12; height: b.height*0.10; color: b.darkC; antialiasing: false }
    Rectangle { x: b.width*0.14; y: b.height*0.54; width: b.width*0.72; height: b.height*0.34; color: b.furC; antialiasing: false }
    Rectangle { x: b.width*0.20; y: b.height*0.86; width: b.width*0.18; height: b.height*0.12; color: b.darkC; antialiasing: false }
    Rectangle { x: b.width*0.62; y: b.height*0.86; width: b.width*0.18; height: b.height*0.12; color: b.darkC; antialiasing: false }
}
