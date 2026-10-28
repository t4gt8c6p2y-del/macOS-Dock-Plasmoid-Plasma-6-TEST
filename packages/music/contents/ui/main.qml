pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as P5Support
import "components"
import "widget"

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    WidgetActions { id: commonActions }

    PlasmaCore.Action {
        id: playPauseAction
        text: root.isPlaying ? i18n("Pause") : i18n("Play")
        icon.name: root.isPlaying ? "media-playback-pause" : "media-playback-start"
        enabled: root._activePlayer !== null && root._activePlayer !== undefined
        onTriggered: root.togglePlaying()
    }
    PlasmaCore.Action {
        id: nextAction
        text: i18n("Next Track")
        icon.name: "media-skip-forward"
        enabled: root.canGoNext
        onTriggered: root.next()
    }
    PlasmaCore.Action {
        id: previousAction
        text: i18n("Previous Track")
        icon.name: "media-skip-backward"
        enabled: root.canGoPrevious
        onTriggered: root.previous()
    }

    // Phone control path. KDE Connect talks to the phone's media session over
    // Wi-Fi, so pressing play/pause does not make the phone move its audio to
    // this PC (which the Bluetooth/AVRCP commands do). It also gives the cover.
    PlasmaCore.Action {
        id: phoneSourceAction
        text: root._kcPreferred ? i18n("Phone: use Bluetooth controls")
                                : i18n("Phone: use KDE Connect")
        icon.name: "smartphone"
        onTriggered: plasmoid.configuration.phoneSource = root._kcPreferred ? 0 : 1
    }

    Plasmoid.contextualActions: [playPauseAction, nextAction, previousAction, phoneSourceAction].concat(commonActions.list)
    preferredRepresentation: fullRepresentation

    readonly property bool _shouldShow: {
        if (!plasmoid.configuration.autoHideEnabled) return true
        return root.isPlaying
    }

    function _updateVisibility() {
        if (_shouldShow) {
            root.visible = true
            _autoHideTimer.stop()
        } else if (plasmoid.configuration.autoHideEnabled) {
            _autoHideTimer.restart()
        }
    }

    on_ShouldShowChanged: _updateVisibility()

    // Initialise the auto-hide timer when the widget starts with no media playing.
    Component.onCompleted: _updateVisibility()

    Timer {
        id: _autoHideTimer
        interval: plasmoid.configuration.autoHideTimeout * 1000
        repeat: false
        onTriggered: root.visible = false
    }

    MacOSColors {
        id: colors
        styleMode: plasmoid.configuration.styleMode
        appearance: plasmoid.configuration.appearance
        foregroundDarkOverride: isSolid && root._hasSampledColor ? root._sampledIsDark : null
    }
    readonly property var colorTokens: colors

    FontLoader { id: sfThin;    source: Qt.resolvedUrl("../fonts/sf_pro_display_thin.otf") }
    FontLoader { id: sfRegular; source: Qt.resolvedUrl("../fonts/sf_pro_display_regular.otf") }
    // ── MPRIS ─────────────────────────────────────────────────────────────

    Mpris.Mpris2Model { id: mpris2Model }

    // ── KDE Connect (phone media over Wi-Fi) ─────────────────────────────
    // 0 = Bluetooth (MPRIS) only, 1 = KDE Connect first (falls back to
    // Bluetooth when KDE Connect has nothing to show).
    readonly property bool _kcPreferred: plasmoid.configuration.phoneSource === 1

    // Mimics the subset of the MPRIS player API the widget uses, so the rest
    // of the code does not care where the track comes from.
    QtObject {
        id: kcPlayer
        property string deviceId: ""
        property string deviceName: ""
        property string identity: deviceName
        property string track: ""
        property string artist: ""
        property string album: ""
        property string artUrl: ""
        property real length: 0      // microseconds
        property real position: 0    // microseconds
        property int playbackStatus: Mpris.PlaybackStatus.Stopped
        property bool canGoNext: true
        property bool canGoPrevious: true
        property bool canPlay: true
        property bool canPause: true

        function Play()      { root._kcSend("Play") }
        function Pause()     { root._kcSend("Pause") }
        function PlayPause() { root._kcSend(playbackStatus === Mpris.PlaybackStatus.Playing ? "Pause" : "Play") }
        function Next()      { root._kcSend("Next") }
        function Previous()  { root._kcSend("Previous") }
        function Seek(offsetUs) { root._kcSeek(Math.max(0, Math.round((position + offsetUs) / 1000))) }
    }

    readonly property bool _isKc: _activePlayer === kcPlayer

    readonly property string _kcScript:
        decodeURIComponent(Qt.resolvedUrl("scripts/kdeconnect-media.sh").toString().replace(/^file:\/\//, ""))
    function _kcCmd(args) {
        return "sh '" + _kcScript.replace(/'/g, "'\\''") + "' " + args
    }
    property bool _kcBusy: false

    P5Support.DataSource {
        id: kcRunner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.indexOf(" poll") >= 0) {
                root._kcBusy = false
                root._applyKc(data["stdout"])
            }
        }
    }

    function _kcPoll() {
        if (_kcBusy) return
        _kcBusy = true
        kcRunner.connectSource(_kcCmd("poll"))
    }
    function _kcSend(action) {
        if (kcPlayer.deviceId === "") return
        kcRunner.connectSource(_kcCmd("send " + kcPlayer.deviceId + " " + action + " " + Date.now()))
        // Refresh quickly so the play/pause state follows the command.
        _kcRefreshTimer.restart()
    }
    function _kcSeek(ms) {
        if (kcPlayer.deviceId === "") return
        kcRunner.connectSource(_kcCmd("seek " + kcPlayer.deviceId + " " + ms + " " + Date.now()))
    }

    Timer {
        id: _kcRefreshTimer
        interval: 700
        onTriggered: root._kcPoll()
    }

    // Light poll while KDE Connect is wanted. It also runs (more slowly) while
    // the widget is auto-hidden, otherwise it could never reappear.
    Timer {
        interval: root.visible ? 1500 : 4000
        repeat: true
        running: root._kcPreferred
        triggeredOnStart: true
        onTriggered: root._kcPoll()
    }

    // The poll script prints: <id> TAB <name json> TAB <properties json>
    function _applyKc(text) {
        var chosen = null
        var lines = (text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("\t")
            if (parts.length < 3) continue
            try {
                var nj = JSON.parse(parts[1])
                var name = nj.data
                if (Array.isArray(name)) name = name[0]
                var pj = JSON.parse(parts[2])
                var m = Array.isArray(pj.data) ? pj.data[0] : pj.data
                var pv = function(k) {
                    var e = m[k]
                    return (e !== undefined && e !== null && e.data !== undefined) ? e.data : e
                }
                var title = pv("title") || ""
                if (title === "") continue
                var cand = {
                    id: parts[0], name: name || "", title: title,
                    artist: pv("artist") || "", album: pv("album") || "",
                    playing: pv("isPlaying") === true,
                    posMs: pv("position") || 0, lenMs: pv("length") || 0,
                    art: pv("localAlbumArtUrl") || ""
                }
                if (!chosen || (cand.playing && !chosen.playing)) chosen = cand
            } catch (e) {
                // malformed line: ignore it
            }
        }

        if (!chosen) {
            // Nothing to show any more: empty the player so it drops out.
            if (kcPlayer.track !== "" || kcPlayer.artist !== "") {
                kcPlayer.track = ""
                kcPlayer.artist = ""
                kcPlayer.album = ""
                kcPlayer.artUrl = ""
                kcPlayer.playbackStatus = Mpris.PlaybackStatus.Stopped
            }
            return
        }

        var art = chosen.art
        if (art !== "" && art.indexOf("://") < 0 && art.charAt(0) === "/") art = "file://" + art
        var status = chosen.playing ? Mpris.PlaybackStatus.Playing : Mpris.PlaybackStatus.Paused
        var posUs = chosen.posMs * 1000
        var trackChanged = chosen.title !== kcPlayer.track || chosen.artist !== kcPlayer.artist

        kcPlayer.deviceId = chosen.id
        kcPlayer.deviceName = chosen.name
        kcPlayer.length = chosen.lenMs * 1000
        // The phone's position is only refreshed now and then; keep our own
        // running clock unless the phone's value really differs (seek, new track).
        if (trackChanged || status !== kcPlayer.playbackStatus
                || Math.abs(posUs - root.position) > 2500000)
            kcPlayer.position = posUs
        kcPlayer.album = chosen.album
        kcPlayer.artUrl = art
        kcPlayer.playbackStatus = status
        kcPlayer.artist = chosen.artist
        kcPlayer.track = chosen.title
    }

    function _isPlayerAllowed(identity) {
        var f = (plasmoid.configuration.playerFilter || "").toLowerCase()
        if (f === "") return true
        var list = f.split(",")
        var id = (identity || "").toLowerCase()
        var inList = false
        for (var i = 0; i < list.length; i++) {
            if (list[i].trim() === id) { inList = true; break }
        }
        return plasmoid.configuration.filterMode === 1 ? !inList : inList
    }

    // Bumped whenever the list of MPRIS players changes, so the player choice
    // below is re-evaluated (rowCount() alone is not reactive).
    property int _modelRev: 0
    Connections {
        target: mpris2Model
        function onRowsInserted() { root._modelRev++ }
        function onRowsRemoved() { root._modelRev++ }
        function onModelReset() { root._modelRev++ }
        function onCurrentPlayerChanged() { root._modelRev++ }
    }

    // Picks the player to display. A player that is actually playing always wins
    // over a paused one, wherever it comes from (a PC app, a browser, or a phone
    // exposed over Bluetooth by BlueZ's mpris-proxy). When several are playing,
    // or none is, the first one (Plasma's own current player) is kept.
    function _pickPlayer() {
        const CONTAINER_ROLE = Qt.UserRole + 1
        var best = null
        var bestScore = 0
        function consider(p) {
            if (!p || !_isPlayerAllowed(p.identity) || !(p.track || p.artist)) return
            // When KDE Connect shows the phone, hide its Bluetooth duplicate
            // (BlueZ names it "<phone name> <app>").
            if (p !== kcPlayer && root._kcPreferred && (kcPlayer.track || kcPlayer.artist)
                    && kcPlayer.deviceName !== ""
                    && (p.identity || "").toLowerCase().indexOf(kcPlayer.deviceName.toLowerCase()) >= 0) return
            var score = p.playbackStatus === Mpris.PlaybackStatus.Playing ? 2 : 1
            if (score > bestScore) { best = p; bestScore = score }
        }
        consider(mpris2Model.currentPlayer)
        for (var i = 1; i < mpris2Model.rowCount(); i++)
            consider(mpris2Model.data(mpris2Model.index(i, 0), CONTAINER_ROLE))
        if (root._kcPreferred) consider(kcPlayer)
        return best
    }

    property var _activePlayer: {
        root._modelRev
        return root._pickPlayer()
    }
    readonly property bool _playerAllowed: {
        var cp = mpris2Model.currentPlayer
        return cp ? _isPlayerAllowed(cp.identity) : true
    }

    readonly property string track:   _activePlayer?.track ?? ""
    readonly property string artist:  _activePlayer?.artist ?? ""
    readonly property string album:   _activePlayer?.album ?? ""
    // Bluetooth (AVRCP) never carries a cover, so when the player gives none we
    // look it up online (iTunes) from the artist + title.
    readonly property string _playerArt: _activePlayer?.artUrl ?? ""
    property string _onlineArt: ""
    property string _onlineArtKey: ""
    property var _onlineArtCache: ({})
    readonly property string _rawAlbumArt: _playerArt !== "" ? _playerArt : _onlineArt
    readonly property string _noAlbumUrl: Qt.resolvedUrl("icons/no_album.png")
    property string albumArt: _noAlbumUrl

    on_RawAlbumArtChanged: {
        if (_rawAlbumArt === "") {
            // Empty for a moment between tracks is normal; only clear if it stays empty.
            _artDebounceTimer.stop()
            _artClearTimer.restart()
            return
        }
        _artClearTimer.stop()
        _artDebounceTimer.restart()
    }

    Timer {
        id: _artClearTimer
        interval: 1500
        onTriggered: root.albumArt = root._noAlbumUrl
    }

    on_PlayerArtChanged: _onlineArtTimer.restart()
    onArtistChanged: _onlineArtTimer.restart()

    Timer {
        id: _onlineArtTimer
        interval: 500
        onTriggered: root._fetchOnlineArt()
    }

    function _normKey(t) {
        return (t || "").toLowerCase().replace(/[\s\-_.,:;!?'"()\[\]&]+/g, "")
    }

    function _fetchOnlineArt() {
        if (_playerArt !== "" || track === "" || artist === "") {
            _onlineArt = ""
            return
        }
        var key = artist + "|" + track
        if (_onlineArtCache[key] !== undefined) {
            _onlineArt = _onlineArtCache[key]
            return
        }
        _onlineArt = ""
        _onlineArtKey = key
        var wantT = _normKey(_cleanTitle(track))
        var wantA = _normKey(_firstArtist(artist))
        if (wantT === "") return

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (root._onlineArtKey !== key) return  // stale
            var url = ""
            if (xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText).results || []
                    var titleOnly = null
                    for (var i = 0; i < res.length; i++) {
                        var it = res[i]
                        if (!it.artworkUrl100) continue
                        var okT = root._normKey(it.trackName).indexOf(wantT) >= 0
                        var okA = wantA !== "" && root._normKey(it.artistName).indexOf(wantA) >= 0
                        if (okT && okA) { url = it.artworkUrl100; break }
                        if (okT && !titleOnly) titleOnly = it.artworkUrl100
                    }
                    if (url === "" && titleOnly) url = titleOnly
                    if (url !== "") url = url.replace("100x100bb", "600x600bb")
                } catch (e) {
                    url = ""
                }
            }
            if (xhr.status === 200) root._onlineArtCache[key] = url
            if (root._playerArt === "" && root.artist + "|" + root.track === key)
                root._onlineArt = url
        }
        xhr.open("GET", "https://itunes.apple.com/search?media=music&entity=song&limit=8&term="
                 + encodeURIComponent(_firstArtist(artist) + " " + _cleanTitle(track)))
        xhr.send()
    }

    Timer {
        id: _artDebounceTimer
        interval: 150
        onTriggered: root.albumArt = root._rawAlbumArt
    }
    readonly property int playbackStatus: _activePlayer?.playbackStatus ?? 0
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canGoPrevious: _activePlayer?.canGoPrevious ?? false
    readonly property bool canGoNext:     _activePlayer?.canGoNext ?? false
    readonly property bool canPlay:  _activePlayer?.canPlay ?? false
    readonly property bool canPause: _activePlayer?.canPause ?? false
    readonly property real _rawLength: _activePlayer?.length ?? 0
    // BlueZ's mpris-proxy (phone over Bluetooth) reports the track duration in
    // milliseconds instead of microseconds. No real track lasts under 1 second,
    // so a tiny value means "milliseconds".
    readonly property bool _lengthInMs: _rawLength > 0 && _rawLength < 1000000
    readonly property real length: _lengthInMs ? _rawLength * 1000 : _rawLength

    property real position: 0
    property bool lyricsActive: false
    property int _flipDirection: 1

    // ── Lyrics data ──────────────────────────────────────────────────────
    property var _syncedLyrics: []
    property string _plainLyrics: ""
    property int _lyricsState: 0   // 0=idle 1=loading 2=loaded 3=error 4=not-found
    property string _lyricsTrackKey: ""
    property int _lyricsFailCount: 0
    readonly property var _lyricsBackoff: [5000, 10000, 20000, 40000, 80000, 160000, 300000]

    onLyricsActiveChanged: {
        if (lyricsActive && _lyricsState === 0 && track !== "")
            _lyricsFetchTimer.restart()
    }

    Timer {
        id: _lyricsFetchTimer
        interval: 400
        onTriggered: root._fetchLyrics()
    }

    Timer {
        id: _lyricsRetryTimer
        repeat: false
        onTriggered: root._fetchLyrics()
    }

    property real _lastPosTick: 0

    Timer {
        id: lyricsPositionTimer
        interval: 80
        running: root.isPlaying && root.lyricsActive
        repeat: true
        onTriggered: {
            var now = Date.now()
            if (root._lastPosTick > 0)
                root.position += (now - root._lastPosTick) * 1000
            root._lastPosTick = now
        }
    }

    function _cleanTitle(t) {
        var c = t.replace(/\s*[\(\[][^\)\]]*[\)\]]/g, "").replace(/\s+-\s+.*$/, "").trim()
        return c !== "" ? c : t
    }

    function _firstArtist(a) {
        var c = a.split(/\s*(?:,|;|\bfeat\b\.?|\bft\b\.?)\s*/i)[0].trim()
        return c !== "" ? c : a
    }

    function _applyLyrics(resp) {
        var synced = resp.syncedLyrics || ""
        root._plainLyrics = resp.plainLyrics || ""
        root._syncedLyrics = synced !== "" ? root._parseLrc(synced, (resp.offset || 0) * 1000) : []
        root._lyricsState = 2
        root._lyricsFailCount = 0
        _lyricsRetryTimer.stop()
    }

    function _lyricsNotFound() {
        root._lyricsState = 4
        root._lyricsFailCount = 0
        _lyricsRetryTimer.stop()
    }

    function _lyricsFailed() {
        root._lyricsState = 3
        root._lyricsFailCount = Math.min(root._lyricsFailCount + 1, root._lyricsBackoff.length - 1)
        _lyricsRetryTimer.interval = root._lyricsBackoff[root._lyricsFailCount]
        _lyricsRetryTimer.restart()
    }

    function _lrclibGet(url, key, cb) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (root._lyricsTrackKey !== key) return  // stale
            cb(xhr.status, xhr.responseText)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    // Picks the best entry of an LRCLIB search result: synced lyrics first,
    // and a duration close to the real one when we know it.
    function _pickLyricsResult(list, durSec) {
        if (!list || !list.length) return null
        var best = null
        for (var i = 0; i < list.length; i++) {
            var it = list[i]
            if (!it.syncedLyrics) continue
            if (durSec > 0 && it.duration > 0 && Math.abs(it.duration - durSec) > 5) continue
            best = it
            break
        }
        if (best) return best
        for (var j = 0; j < list.length; j++) {
            if (list[j].plainLyrics) return list[j]
        }
        return null
    }

    function _fetchLyrics() {
        if (track === "" || artist === "") return
        var key = artist + "|" + track
        if (key === _lyricsTrackKey && _lyricsState === 2) return
        _lyricsTrackKey = key
        _lyricsState = 1

        var base = "https://lrclib.net/api/"
        var durSec = length > 0 ? Math.round(length / 1000000) : 0

        var loose = base + "get"
            + "?artist_name=" + encodeURIComponent(artist)
            + "&track_name=" + encodeURIComponent(track)
        var exact = loose
        if (album !== "")
            exact += "&album_name=" + encodeURIComponent(album)
        if (durSec > 0)
            exact += "&duration=" + durSec

        var search = base + "search"
            + "?track_name=" + encodeURIComponent(root._cleanTitle(track))
            + "&artist_name=" + encodeURIComponent(root._firstArtist(artist))

        function trySearch() {
            root._lrclibGet(search, key, function(status, text) {
                if (status === 200) {
                    try {
                        var pick = root._pickLyricsResult(JSON.parse(text), durSec)
                        if (pick) root._applyLyrics(pick)
                        else root._lyricsNotFound()
                    } catch (e) {
                        root._lyricsFailed()
                    }
                } else if (status === 404) {
                    root._lyricsNotFound()
                } else {
                    root._lyricsFailed()
                }
            })
        }

        function tryLoose() {
            if (loose === exact) { trySearch(); return }
            root._lrclibGet(loose, key, function(status, text) {
                if (status === 200) {
                    try { root._applyLyrics(JSON.parse(text)) }
                    catch (e) { root._lyricsFailed() }
                } else if (status === 404) {
                    trySearch()
                } else {
                    root._lyricsFailed()
                }
            })
        }

        root._lrclibGet(exact, key, function(status, text) {
            if (status === 200) {
                try { root._applyLyrics(JSON.parse(text)) }
                catch (e) { root._lyricsFailed() }
            } else if (status === 404) {
                tryLoose()
            } else {
                root._lyricsFailed()
            }
        })
    }

    function _parseLrc(lrcContent, apiOffsetMs) {
        var lines = lrcContent.split("\n")
        var result = []
        var re = /\[(\d{2}):(\d{2})[.:](\d{2})\](.*)/
        var offsetRe = /\[offset:([+-]?\d+)\]/i
        var lrcOffsetMs = 0
        for (var i = 0; i < lines.length; i++) {
            var om = offsetRe.exec(lines[i])
            if (om) {
                lrcOffsetMs += parseInt(om[1])
                continue
            }
            var m = re.exec(lines[i])
            if (m) {
                result.push({
                    timestamp: parseInt(m[1]) * 60000 + parseInt(m[2]) * 1000 + parseInt(m[3]) * 10
                               + lrcOffsetMs + (apiOffsetMs || 0),
                    text: m[4].trim()
                })
            }
        }
        result.sort(function(a, b) { return a.timestamp - b.timestamp })
        return result
    }

    Connections {
        target: root._activePlayer
        function onPositionChanged() {
            if (root._activePlayer) root.position = root._activePlayer.position
            root._lastPosTick = 0
        }
    }

    Timer {
        id: positionTimer
        interval: 250
        running: root.isPlaying && root.length > 0 && !lyricsPositionTimer.running
        repeat: true
        onTriggered: {
            var now = Date.now()
            if (root._lastPosTick > 0)
                root.position += (now - root._lastPosTick) * 1000
            root._lastPosTick = now
        }
    }

    onTrackChanged: {
        if (track === "" || track === "Not Playing") {
            _artDebounceTimer.stop()
            albumArt = _noAlbumUrl
        }
        root._onlineArt = ""
        _onlineArtTimer.restart()
        root.position = root._lengthInMs ? 0 : (root._activePlayer?.position ?? 0)
        root._lastPosTick = 0
        root._lastSampledUrl = ""
        _scheduleArtRefresh()
        _resampleTimer.restart()
        root._syncedLyrics = []
        root._plainLyrics = ""
        root._lyricsState = 0
        root._lyricsTrackKey = ""
        root._lyricsFailCount = 0
        _lyricsRetryTimer.stop()
        _lyricsFetchTimer.restart()
    }
    Timer {
        id: _resampleTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (root.albumArt !== "" && root.albumArt !== root._lastSampledUrl)
                sampleCanvas.requestPaint()
        }
    }
    onIsPlayingChanged: {
        root.position = root._activePlayer?.position ?? 0
        root._lastPosTick = 0
    }
    onLengthChanged: {
        if (_lengthInMs && root.position > root.length)
            root.position = 0
        if (length > 0 && _lyricsState === 0 && track !== "")
            _lyricsFetchTimer.restart()
    }

    Timer {
        id: artRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (root._activePlayer && root.isPlaying) {
                root._activePlayer.Pause()
                artResumeTimer.start()
            }
        }
    }

    Timer {
        id: artResumeTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (root._activePlayer) root._activePlayer.Play()
        }
    }

    function _scheduleArtRefresh() {
        if (!plasmoid.configuration.artRefreshEnabled) return
        if (root._lengthInMs || root._isKc) return   // never pause a phone's playback
        artRefreshTimer.stop()
        artResumeTimer.stop()
        if (root.isPlaying) artRefreshTimer.start()
    }

    function togglePlaying() {
        if (!root._activePlayer) return
        root._activePlayer.PlayPause()
    }
    function next() {
        if (!root._activePlayer) return
        root._flipDirection = -1
        root._activePlayer.Next()
    }
    function previous() {
        if (!root._activePlayer) return
        root._flipDirection = 1
        root._activePlayer.Previous()
    }
    function seek(positionUs) {
        if (!root._activePlayer) return
        if (root._lengthInMs) return   // Bluetooth (AVRCP) players cannot seek
        var currentPos = root._activePlayer.position ?? root.position
        var offset = positionUs - currentPos
        root._activePlayer.Seek(offset)
        root.position = positionUs
        root._lastPosTick = 0
    }

    function formatTime(us) {
        var totalSec = Math.floor(us / 1000000)
        var h = Math.floor(totalSec / 3600)
        var m = Math.floor((totalSec % 3600) / 60)
        var s = totalSec % 60
        var ss = s < 10 ? "0" + s : "" + s
        if (h > 0) return h + ":" + (m < 10 ? "0" + m : m) + ":" + ss
        return m + ":" + ss
    }

    // ── Album art color sampling ────────────────────────────────────────
    property color _sampledTint: "#000000"
    property color _sampledGradientTop: "#1A1B1E"
    property color _sampledGradientBottom: "#0E0F11"
    property color _sampledPrimaryColor: "#ffffff"
    property bool _hasSampledColor: false
    property bool _sampledIsDark: true

    function _hslToRgb(h, s, l) {
        var c = (1 - Math.abs(2 * l - 1)) * s
        var x = c * (1 - Math.abs((h * 6) % 2 - 1))
        var m = l - c / 2
        var r, g, b
        switch (Math.floor(h * 6) % 6) {
            case 0: r = c; g = x; b = 0; break
            case 1: r = x; g = c; b = 0; break
            case 2: r = 0; g = c; b = x; break
            case 3: r = 0; g = x; b = c; break
            case 4: r = x; g = 0; b = c; break
            case 5: r = c; g = 0; b = x; break
        }
        return Qt.rgba(r + m, g + m, b + m, 1.0)
    }

    function _rgbToHsl(r, g, b) {
        var mx = Math.max(r, g, b), mn = Math.min(r, g, b)
        var l = (mx + mn) / 2, s = 0, h = 0
        if (mx !== mn) {
            var dd = mx - mn
            s = l > 0.5 ? dd / (2 - mx - mn) : dd / (mx + mn)
            if (mx === r)      h = ((g - b) / dd + (g < b ? 6 : 0)) / 6
            else if (mx === g) h = ((b - r) / dd + 2) / 6
            else               h = ((r - g) / dd + 4) / 6
        }
        return { h: h, s: s, l: l }
    }

    property string _lastSampledUrl: ""

    onAlbumArtChanged: {
        if (albumArt !== "") {
            sampleCanvas.loadImage(albumArt)
        } else {
            _hasSampledColor = false
            _sampledTint = "#000000"
            _sampledGradientTop = "#1A1B1E"
            _sampledGradientBottom = "#0E0F11"
            _sampledPrimaryColor = "#ffffff"
            _sampledIsDark = true
            _lastSampledUrl = ""
        }
    }

    Canvas {
        id: sampleCanvas
        width: 64
        height: 64
        visible: true
        opacity: 0

        Component.onCompleted: {
            if (root.albumArt !== "") loadImage(root.albumArt)
        }

        onImageLoaded: {
            if (root.albumArt !== "" && root.albumArt !== root._lastSampledUrl) {
                root._lastSampledUrl = root.albumArt
                _resampleTimer.stop()
                requestPaint()
            }
        }

        onPaint: {
            var url = root.albumArt
            if (!url || !isImageLoaded(url)) return

            var ctx = getContext("2d")
            ctx.reset()
            ctx.drawImage(url, 0, 0, 64, 64)

            var imgData = ctx.getImageData(0, 0, 64, 64)
            var d = imgData.data
            var pixels = []
            for (var i = 0; i < d.length; i += 4) {
                if (d[i+3] < 128) continue
                pixels.push([d[i], d[i+1], d[i+2]])
            }
            if (pixels.length === 0) return

            function medianCut(px, depth) {
                if (depth === 0 || px.length === 0) {
                    var rS = 0, gS = 0, bS = 0
                    for (var j = 0; j < px.length; j++) {
                        rS += px[j][0]; gS += px[j][1]; bS += px[j][2]
                    }
                    var n = px.length || 1
                    return [{ r: rS/n/255, g: gS/n/255, b: bS/n/255, count: px.length }]
                }

                var rMin = 255, rMax = 0, gMin = 255, gMax = 0, bMin = 255, bMax = 0
                for (var j = 0; j < px.length; j++) {
                    var p = px[j]
                    if (p[0] < rMin) rMin = p[0]; if (p[0] > rMax) rMax = p[0]
                    if (p[1] < gMin) gMin = p[1]; if (p[1] > gMax) gMax = p[1]
                    if (p[2] < bMin) bMin = p[2]; if (p[2] > bMax) bMax = p[2]
                }
                var rR = rMax - rMin, gR = gMax - gMin, bR = bMax - bMin
                var ch = rR >= gR && rR >= bR ? 0 : (gR >= bR ? 1 : 2)

                px.sort(function(a, b) { return a[ch] - b[ch] })
                var mid = Math.floor(px.length / 2)

                return medianCut(px.slice(0, mid), depth - 1)
                       .concat(medianCut(px.slice(mid), depth - 1))
            }

            var buckets = medianCut(pixels, 3)

            var accentIdx = 0, maxSat = -1
            for (var i = 0; i < buckets.length; i++) {
                var hsl = root._rgbToHsl(buckets[i].r, buckets[i].g, buckets[i].b)
                buckets[i].h = hsl.h; buckets[i].s = hsl.s; buckets[i].l = hsl.l
                buckets[i].lum = 0.299 * buckets[i].r + 0.587 * buckets[i].g + 0.114 * buckets[i].b
                var score = hsl.s * (0.3 + 0.7 * (1 - Math.abs(2 * hsl.l - 1)))
                if (score > maxSat) { maxSat = score; accentIdx = i }
            }

            var sorted = buckets.slice().sort(function(a, b) { return b.count - a.count })
            var dominant = sorted[0]
            var secondary = sorted.length > 1 ? sorted[1] : sorted[0]
            var accent = buckets[accentIdx]

            var avgSat = 0
            for (var j = 0; j < buckets.length; j++)
                avgSat += buckets[j].s
            avgSat /= buckets.length
            var isMono = avgSat < 0.12

            if (isMono) {
                root._sampledTint = root._hslToRgb(0, 0, Math.min(dominant.l, 0.30))
                root._sampledGradientTop = root._hslToRgb(0, 0, 0.15 + dominant.l * 0.35)
                root._sampledGradientBottom = root._hslToRgb(0, 0, 0.06 + dominant.l * 0.20)
                root._sampledPrimaryColor = Qt.rgba(1, 1, 1, 1)
            } else {
                root._sampledTint = root._hslToRgb(accent.h,
                    Math.min(accent.s, 0.5),
                    Math.min(accent.l, 0.30))
                root._sampledGradientTop = root._hslToRgb(dominant.h,
                    Math.max(dominant.s, 0.30),
                    0.15 + dominant.l * 0.35)
                root._sampledGradientBottom = root._hslToRgb(
                    secondary.h !== dominant.h ? secondary.h : dominant.h,
                    Math.max(secondary.s, 0.25),
                    0.06 + secondary.l * 0.20)
                root._sampledPrimaryColor = root._hslToRgb(accent.h,
                    Math.max(accent.s, 0.55),
                    Math.max(accent.l, 0.75))
            }

            // The generated solid gradient is deliberately dark even when
            // the source cover is bright, so its content must stay light.
            root._sampledIsDark = true
            root._hasSampledColor = true
        }
    }


    // ── UI ─────────────────────────────────────────────────────────────────

    fullRepresentation: Item {
        id: full
        Layout.preferredWidth:  full.width  > 0 ? full.width  : 440
        Layout.preferredHeight: full.height > 0 ? full.height : 220
        Layout.minimumWidth: 80
        Layout.minimumHeight: 60

        readonly property real _ar: full.width / Math.max(1, full.height)
        readonly property string _layout:
            _ar >= 3.0  ? "bar"
          : _ar >= 1.6  ? "wide"
          : _ar <= 0.85 && full.height >= full.width * 1.55 ? "tallwide"
          :               "square"

        LiquidGlass {
            id: glass
            visibilitySource: root
            anchors.fill: parent
            radius: plasmoid.configuration.cornerRadius
            roundness: plasmoid.configuration.roundnessX10 / 10
            refractThickness: plasmoid.configuration.refractThickness
            refractIOR: plasmoid.configuration.refractIORx100 / 100
            refractScale: plasmoid.configuration.refractScale
            tint: colors.isGlass && root._hasSampledColor ? root._sampledTint : colors.glassTint
            tintAlpha: colors.isGlass && root._hasSampledColor
                ? Math.max(plasmoid.configuration.tintAlphaPct / 100, 0.15)
                : plasmoid.configuration.tintAlphaPct / 100
            chromaStrength: plasmoid.configuration.chromaStrengthPct / 100
            specStrength: plasmoid.configuration.specStrengthPct / 100
            blurRadius: plasmoid.configuration.blurRadiusPx
            blurAlgorithm: plasmoid.configuration.blurAlgorithm
            realtimeRefraction: plasmoid.configuration.realtimeRefraction
            fallbackOpacity: colors.glassFallbackOpacity
            solidMode: colors.isSolid
            solidColor: colors.isSolid && root._hasSampledColor ? root._sampledGradientTop : colors.solidBackground
            solidColorBottom: colors.isSolid && root._hasSampledColor ? root._sampledGradientBottom : "transparent"
            overlayDarken: root.lyricsActive && full._layout === "tallwide"
                ? Qt.vector4d(root._sampledGradientBottom.r, root._sampledGradientBottom.g, root._sampledGradientBottom.b, 0.55)
                : Qt.vector4d(0, 0, 0, 0)
        }

        Loader {
            id: activeLayout
            anchors.fill: parent
            sourceComponent: full._layout === "square" ? squareLayoutComponent
                           : full._layout === "tallwide" ? tallWideLayoutComponent
                           : full._layout === "wide" ? wideLayoutComponent
                           : barLayoutComponent
        }

        Component {
            id: squareLayoutComponent
            SquareLayout {
                anchors.fill: parent
                colors: root.colorTokens
                cornerRadius: plasmoid.configuration.cornerRadius
                roundness: plasmoid.configuration.roundnessX10 / 10
                fontFamily: sfRegular.name
                fontFamilyThin: sfThin.name
                track: root.track
                artist: root.artist
                albumArt: root.albumArt
                isPlaying: root.isPlaying
                canGoPrevious: root.canGoPrevious
                canGoNext: root.canGoNext
                canPlay: root.canPlay
                canPause: root.canPause
                position: root.position
                length: root.length
                onTogglePlaying: root.togglePlaying()
                onNextTrack: root.next()
                onPreviousTrack: root.previous()
                onSeek: function(pos) { root.seek(pos) }
                formatTime: root.formatTime
            }
        }

        Component {
            id: tallWideLayoutComponent
            TallWideLayout {
                anchors.fill: parent
                colors: root.colorTokens
                accentColor: root._hasSampledColor ? root._sampledPrimaryColor : root.colorTokens.foreground
                lyricsAccentColor: root._hasSampledColor ? root._sampledTint : Qt.rgba(1, 1, 1, 0.35)
                flipDirection: root._flipDirection
                lyricsActive: root.lyricsActive
                onToggleLyrics: root.lyricsActive = !root.lyricsActive
                syncedLyrics: root._syncedLyrics
                plainLyrics: root._plainLyrics
                lyricsState: root._lyricsState
                lyricsPositionMs: root.position / 1000
                lyricsBlur: plasmoid.configuration.lyricsBlur
                showTrackTitleInLyrics: plasmoid.configuration.showTrackTitleInLyrics
                lyricsActiveOpacity: plasmoid.configuration.lyricsActiveOpacity / 100
                lyricsInactiveOpacity: plasmoid.configuration.lyricsInactiveOpacity / 100
                lyricsFontSizeFactor: plasmoid.configuration.lyricsFontSizeTall / 1000
                fontFamily: sfRegular.name
                fontFamilyThin: sfThin.name
                track: root.track
                artist: root.artist
                albumArt: root.albumArt
                isPlaying: root.isPlaying
                canGoPrevious: root.canGoPrevious
                canGoNext: root.canGoNext
                canPlay: root.canPlay
                canPause: root.canPause
                position: root.position
                length: root.length
                onTogglePlaying: root.togglePlaying()
                onNextTrack: root.next()
                onPreviousTrack: root.previous()
                onSeek: function(pos) { root.seek(pos) }
                onRetryLyrics: root._fetchLyrics()
                formatTime: root.formatTime
            }
        }

        Component {
            id: wideLayoutComponent
            WideLayout {
                anchors.fill: parent
                colors: root.colorTokens
                accentColor: root._hasSampledColor ? root._sampledPrimaryColor : root.colorTokens.foreground
                lyricsAccentColor: root._hasSampledColor ? root._sampledTint : Qt.rgba(1, 1, 1, 0.35)
                flipDirection: root._flipDirection
                lyricsActive: root.lyricsActive
                onToggleLyrics: root.lyricsActive = !root.lyricsActive
                syncedLyrics: root._syncedLyrics
                plainLyrics: root._plainLyrics
                lyricsState: root._lyricsState
                lyricsPositionMs: root.position / 1000
                lyricsBlur: plasmoid.configuration.lyricsBlur
                showTrackTitleInLyrics: plasmoid.configuration.showTrackTitleInLyrics
                lyricsActiveOpacity: plasmoid.configuration.lyricsActiveOpacity / 100
                lyricsInactiveOpacity: plasmoid.configuration.lyricsInactiveOpacity / 100
                lyricsFontSizeFactor: plasmoid.configuration.lyricsFontSizeWide / 1000
                fontFamily: sfRegular.name
                fontFamilyThin: sfThin.name
                track: root.track
                artist: root.artist
                albumArt: root.albumArt
                isPlaying: root.isPlaying
                canGoPrevious: root.canGoPrevious
                canGoNext: root.canGoNext
                canPlay: root.canPlay
                canPause: root.canPause
                position: root.position
                length: root.length
                onTogglePlaying: root.togglePlaying()
                onNextTrack: root.next()
                onPreviousTrack: root.previous()
                onSeek: function(pos) { root.seek(pos) }
                onRetryLyrics: root._fetchLyrics()
                formatTime: root.formatTime
            }
        }

        Component {
            id: barLayoutComponent
            BarLayout {
                anchors.fill: parent
                colors: root.colorTokens
                accentColor: root._hasSampledColor ? root._sampledPrimaryColor : root.colorTokens.foreground
                cornerRadius: plasmoid.configuration.cornerRadius
                flipDirection: root._flipDirection
                fontFamily: sfRegular.name
                fontFamilyThin: sfThin.name
                track: root.track
                artist: root.artist
                albumArt: root.albumArt
                isPlaying: root.isPlaying
                canGoPrevious: root.canGoPrevious
                canGoNext: root.canGoNext
                canPlay: root.canPlay
                canPause: root.canPause
                position: root.position
                length: root.length
                onTogglePlaying: root.togglePlaying()
                onNextTrack: root.next()
                onPreviousTrack: root.previous()
                onSeek: function(pos) { root.seek(pos) }
                formatTime: root.formatTime
            }
        }
    }
}
