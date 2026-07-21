import QtQuick 2.6
import Nemo.Ngf 1.0

// Isolated in its own file so a missing Ngf module only breaks this Loader, not the app.
Item {
    function play() { effect.play() }
    NonGraphicalFeedback { id: effect; event: "press" }
}
