import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "."

// A small audio visualizer for the Omarchy bar.
//
// cava runs headless with raw ASCII output: one line per frame, one value per
// bar, separated by semicolons. The values arrive already scaled to whole
// pixels of bar height and are drawn as rounded bars in the theme's bar
// foreground (or accent) color, so the widget follows theme switches.
//
// The work is kept to what can be seen:
// - cava processes live in CavaHub and are shared by every copy of the widget
//   with the same config, on every monitor;
// - a channel only runs cava while something plays into the watched output;
// - identical frames are dropped before they reach QML;
// - a widget lets go of its channel while a fullscreen window covers the bar
//   or while the compositor stops drawing the bar (lock screen, screensaver).
BarWidget {
  id: root
  moduleName: "syzyf97.cava"

  readonly property int barCount: clampInt(setting("bars", 10), 4, 32)
  readonly property int framerate: clampInt(setting("framerate", 20), 10, 60)
  readonly property bool useAccent: String(setting("color", "foreground")).toLowerCase() === "accent"
  readonly property bool hideWhenSilent: isOn(setting("hideWhenSilent", "Off"))

  // Frequency range. cava refuses a config whose lower cutoff is not below the
  // higher one, so keep at least 100 Hz between them instead of letting cava
  // exit and restart in a loop.
  readonly property int lowFreq: clampInt(setting("lowFreq", 50), 20, 19900)
  readonly property int highFreq: Math.max(lowFreq + 100, clampInt(setting("highFreq", 10000), 120, 20000))
  readonly property int sensitivity: clampInt(setting("sensitivity", 100), 10, 5000)
  readonly property bool autoSensitivity: isOn(setting("autoSensitivity", "On"))

  // Audio source. The key is audioSource because the bar reserves "source"
  // (with "type" and "exec") for custom user modules. "output" follows the
  // default output (what is playing), "input" follows the default microphone,
  // anything else is a PipeWire node name. cava records a sink through its
  // monitor, so a bare sink name gets ".monitor" appended. Names are limited to
  // characters PipeWire uses, which also keeps the value from breaking out of
  // its line in the cava config.
  readonly property string sourceSetting: String(setting("audioSource", "output")).trim()
  readonly property var audioNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property string cavaSource: {
    var value = sourceSetting
    var lower = value.toLowerCase()
    if (lower === "" || lower === "output" || lower === "auto") return "auto"
    if (lower === "input" || lower === "auto_input") return "auto_input"
    if (!/^[A-Za-z0-9._:@+-]+$/.test(value)) return "auto"
    if (/\.monitor$/.test(value)) return value
    for (var i = 0; i < audioNodes.length; i++) {
      var node = audioNodes[i]
      if (node && node.isSink && !node.isStream && String(node.name) === value) return value + ".monitor"
    }
    return value
  }
  readonly property string sourceLabel: {
    if (cavaSource === "auto") return "Output"
    if (cavaSource === "auto_input") return "Microphone"
    var name = cavaSource.replace(/\.monitor$/, "")
    for (var i = 0; i < audioNodes.length; i++) {
      var node = audioNodes[i]
      if (node && !node.isStream && String(node.name) === name) return node.description || node.nickname || name
    }
    return name
  }

  readonly property color barColor: useAccent
    ? Color.accent
    : (bar ? bar.barForeground : Color.foreground)

  // Geometry. Along the bar: thin bars with a gap; across the bar: a bit more
  // than half of the bar thickness, so it sits visually like an icon.
  readonly property real thickness: Math.max(2, Math.round(Style.spaceReal(3)))
  readonly property real gap: Math.max(1, Math.round(Style.spaceReal(2)))
  readonly property real reach: Math.round(barSize * 0.55)
  readonly property real minReach: Math.max(2, thickness - 1)
  readonly property real padding: Style.spaceReal(8)
  // One cava step per pixel the bars can grow: finer values would move bars
  // by fractions of a pixel and repaint for nothing.
  readonly property int steps: Math.max(1, Math.round(reach - minReach))

  function clampInt(value, min, max) {
    var n = Math.round(Number(value))
    if (!isFinite(n)) n = min
    return Math.max(min, Math.min(max, n))
  }

  function isOn(value) {
    return value === true || String(value).toLowerCase() === "on" || String(value) === "true"
  }

  // sleep_timer lets cava idle on its own when a microphone is silent.
  readonly property string cavaConfig: [
    "[general]",
    "bars=" + barCount,
    "framerate=" + framerate,
    "sleep_timer=2",
    "lower_cutoff_freq=" + lowFreq,
    "higher_cutoff_freq=" + highFreq,
    "sensitivity=" + sensitivity,
    "autosens=" + (autoSensitivity ? 1 : 0),
    "[input]",
    "method=pipewire",
    "source=" + cavaSource,
    "[output]",
    "method=raw",
    "raw_target=/dev/stdout",
    "data_format=ascii",
    "ascii_max_range=" + steps,
    "bar_delimiter=59",
    "frame_delimiter=10",
    "channels=mono",
    "[smoothing]",
    "noise_reduction=77",
    ""
  ].join("\n")

  // --- Visibility --------------------------------------------------------------

  readonly property var barWindow: root.QsWindow.window
  readonly property var hyprMonitor: barWindow && barWindow.screen ? Hyprland.monitorFor(barWindow.screen) : null
  // Only a real fullscreen window (mode 2) hides the bar; a maximized one
  // leaves it visible.
  readonly property bool coveredByFullscreen: {
    var workspace = hyprMonitor ? hyprMonitor.activeWorkspace : null
    if (!workspace || !workspace.hasFullscreen) return false
    var toplevels = workspace.toplevels ? workspace.toplevels.values : []
    for (var i = 0; i < toplevels.length; i++) {
      var ipc = toplevels[i] ? toplevels[i].lastIpcObject : null
      if (ipc && ipc.fullscreen === 2) return true
    }
    return false
  }

  // Hyprland details of toplevels are only refreshed on request.
  onHyprMonitorChanged: Hyprland.refreshToplevels()
  Connections {
    target: root.hyprMonitor ? root.hyprMonitor.activeWorkspace : null
    function onHasFullscreenChanged() { Hyprland.refreshToplevels() }
  }

  // When the compositor stops drawing the bar (session lock, screensaver on
  // top), the window stops presenting frames even though the bars keep
  // changing. Count bar changes since the last presented frame; after about
  // two seconds of changes nobody saw, let go of cava. Letting go resets the
  // bars, which is itself a change waiting to be drawn, so the first frame the
  // compositor presents again brings cava back.
  property int unseenChanges: 0
  property bool renderStalled: false

  Connections {
    target: root.Window.window
    function onFrameSwapped() {
      root.unseenChanges = 0
      if (root.renderStalled) root.renderStalled = false
    }
  }

  readonly property bool shouldListen: barWindow !== null && !coveredByFullscreen && !renderStalled

  // --- Channel -------------------------------------------------------------------

  property var channel: null
  property var levels: []
  property bool silent: true

  function applyFrame(line) {
    var parts = line.split(";")
    var next = []
    var loud = false
    for (var i = 0; i < barCount; i++) {
      var v = Number(parts[i]) / steps
      if (!isFinite(v)) v = 0
      v = Math.max(0, Math.min(1, v))
      if (v > 0) loud = true
      next.push(v)
    }
    levels = next
    if (loud) {
      silenceTimer.stop()
      silent = false
    } else if (!silent && !silenceTimer.running) {
      silenceTimer.restart()
    }
    if (visible && ++unseenChanges > framerate * 2) renderStalled = true
  }

  function resetBars() {
    levels = []
    silenceTimer.stop()
    silent = true
  }

  // Settings arrive right after the widget is created and several can change
  // at once, so channel changes are debounced instead of following every step.
  function syncChannel() {
    var wanted = shouldListen ? cavaConfig : ""
    if (channel && channel.config === wanted) return
    if (channel) {
      CavaHub.release(channel)
      channel = null
      resetBars()
    }
    if (wanted !== "") channel = CavaHub.acquire(cavaConfig, cavaSource)
  }

  onCavaConfigChanged: syncTimer.restart()
  onShouldListenChanged: {
    console.debug("syzyf97.cava: widget on " + (barWindow && barWindow.screen ? barWindow.screen.name : "?")
      + (shouldListen ? " listening" : " paused (fullscreen " + coveredByFullscreen + ", render stalled " + renderStalled + ")"))
    syncTimer.restart()
  }
  Component.onCompleted: syncTimer.restart()
  Component.onDestruction: if (channel) CavaHub.release(channel)

  Timer {
    id: syncTimer
    interval: 100
    onTriggered: root.syncChannel()
  }

  Timer {
    id: silenceTimer
    interval: 1000
    onTriggered: root.silent = true
  }

  Connections {
    target: root.channel
    function onFrame(line) { root.applyFrame(line) }
    function onStopped() { root.resetBars() }
  }

  visible: (!channel || channel.available) && !(hideWhenSilent && silent)
  implicitWidth: vertical ? barSize : content.width + padding * 2
  implicitHeight: vertical ? content.height + padding * 2 : barSize

  Grid {
    id: content
    anchors.centerIn: parent
    // Only columns is bound: the row count follows from it, so the Grid never
    // sees a transient rows*columns smaller than the number of bars.
    columns: root.vertical ? 1 : root.barCount
    spacing: root.gap
    opacity: root.silent ? 0.45 : 1

    Behavior on opacity { NumberAnimation { duration: 200 } }

    Repeater {
      model: root.barCount

      Item {
        required property int index
        readonly property real level: index < root.levels.length ? root.levels[index] : 0
        readonly property real length: root.minReach + level * (root.reach - root.minReach)

        width: root.vertical ? root.reach : root.thickness
        height: root.vertical ? root.thickness : root.reach

        Rectangle {
          anchors.centerIn: parent
          width: root.vertical ? parent.length : root.thickness
          height: root.vertical ? root.thickness : parent.length
          radius: root.thickness / 2
          color: root.barColor
        }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.bar) root.bar.run("omarchy-launch-or-focus-tui cava")
    onContainsMouseChanged: {
      if (!root.bar) return
      if (containsMouse) root.bar.showTooltip(root, "Cava · " + root.sourceLabel)
      else root.bar.hideTooltip(root)
    }
  }
}
