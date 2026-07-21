import QtQuick 2.6
import Sailfish.Silica 1.0

// Procedural pixel view of the warren: a mound with burrow holes, badgers at work, and the
// structures you've raised. It grows with every build. Two-frame animation for a little life.
Canvas {
    id: view

    property int frame: 0
    property int population: 4
    property int stage: 0
    property var counts: ({})   // building key -> count

    property var _seed: 0
    function _srand(s) { _seed = s }
    function _rnd() { _seed = (_seed * 1103515245 + 12345) % 2147483648; return _seed / 2147483648 }

    function shown(n, cap) {
        if (!n || n <= 0) return 0
        return Math.min(cap, 1 + Math.floor(Math.log(n) / Math.LN2 / 1.1))
    }

    Timer {
        interval: 700; running: view.visible && Qt.application.active; repeat: true
        onTriggered: { view.frame = (view.frame + 1) % 2; view.requestPaint() }
    }
    Connections { target: Game; onStateChanged: view.requestPaint() }

    onPaint: {
        var ctx = getContext("2d")
        var c = Math.max(4, Math.floor(width / 60))
        var cols = Math.floor(width / c), rows = Math.floor(height / c)
        function put(x, y, col) {
            if (x < 0 || y < 0 || x >= cols || y >= rows) return
            ctx.fillStyle = col; ctx.fillRect(x * c, y * c, c, c)
        }
        // sky + earth
        ctx.fillStyle = "#20242e"; ctx.fillRect(0, 0, width, height)
        var horizon = Math.floor(rows * 0.42)
        ctx.fillStyle = "#3a2f26"; ctx.fillRect(0, horizon * c, width, height)
        _srand(9)
        for (var y = horizon; y < rows; y++)
            for (var x = 0; x < cols; x++) {
                var r = _rnd()
                if (r < 0.06) put(x, y, "#332a22")
                else if (r < 0.09) put(x, y, "#443a2e")
            }
        // the mound
        var cx = Math.floor(cols / 2)
        for (x = 0; x < cols; x++) {
            var h = Math.floor((horizon) * (0.4 + 0.6 * Math.max(0, 1 - Math.abs(x - cx) / (cols * 0.5))))
            for (y = horizon - h; y < horizon; y++) put(x, y, "#4a3d30")
        }
        // burrow holes
        var burrows = shown(counts["burrow"], 5)
        _srand(21)
        for (var i = 0; i < burrows; i++) {
            var bx = Math.floor(cols * (0.15 + 0.7 * _rnd()))
            var by = horizon - 1 - Math.floor(3 * _rnd())
            put(bx, by, "#161018"); put(bx + 1, by, "#161018"); put(bx, by - 1, "#161018")
        }
        // granary (yellow), workshop (grey), mineshaft (dark), trading post (teal), barracks (red)
        function hut(kx, ky, col, col2) {
            put(kx, ky, col); put(kx + 1, ky, col); put(kx, ky - 1, col2); put(kx + 1, ky - 1, col)
        }
        _srand(37)
        for (i = 0; i < shown(counts["granary"], 4); i++)
            hut(Math.floor(cols * (0.1 + 0.8 * _rnd())), horizon + 2 + Math.floor(3 * _rnd()), "#c9a227", "#e0b23a")
        _srand(41)
        for (i = 0; i < shown(counts["workshop"], 4); i++)
            hut(Math.floor(cols * (0.1 + 0.8 * _rnd())), horizon + 2 + Math.floor(4 * _rnd()), "#8a8078", "#a8a098")
        _srand(53)
        for (i = 0; i < shown(counts["mineshaft"], 3); i++) {
            var mx = Math.floor(cols * (0.15 + 0.7 * _rnd()))
            put(mx, horizon, "#1a1a20"); put(mx + 1, horizon, "#1a1a20"); put(mx, horizon - 1, "#2a2a30")
        }
        _srand(59)
        for (i = 0; i < shown(counts["tradingpost"], 2); i++)
            hut(Math.floor(cols * (0.2 + 0.6 * _rnd())), horizon + 3 + Math.floor(3 * _rnd()), "#2a9d8f", "#3ab5a6")
        _srand(67)
        for (i = 0; i < shown(counts["barracks"], 2); i++)
            hut(Math.floor(cols * (0.2 + 0.6 * _rnd())), horizon + 2 + Math.floor(2 * _rnd()), "#9a3a3a", "#b85050")
        // badgers at work: dark bodies with a pale stripe, wandering
        _srand(101)
        var n = Math.min(16, population)
        for (i = 0; i < n; i++) {
            var wx = Math.floor(cols * (0.08 + 0.84 * _rnd()))
            var wy = horizon + 1 + Math.floor((rows - horizon - 2) * _rnd())
            var off = (frame === 0 ? 0 : (i % 2 === 0 ? 1 : -1))
            put(wx + off, wy, "#2b2b30")
            put(wx + off, wy - 1, "#e6e0d4")  // the badger's pale blaze
        }
    }
}
