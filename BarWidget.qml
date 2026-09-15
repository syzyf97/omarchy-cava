import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// A small audio visualizer for the Omarchy bar.
//
// cava runs headless with raw ASCII output: one line per frame, one value per
// bar (0..100), separated by semicolons. Each line is mapped onto a row of
// rounded bars painted in the theme's bar foreground (or accent) color, so the
// widget follows theme switches without any extra wiring.
BarWidget {
  id: root
  moduleName: "syzyf97.cava"

  readonly property int barCount: clampInt(setting("bars", 10), 4, 32)
  readonly property int framerate: clampInt(setting("framerate", 30), 10, 60)
  readonly property bool useAccent: String(setting("color", "foreground")).toLowerCase() === "accent"
  readonly property bool hideWhenSilent: isOn(setting("hideWhenSilent", "Off"))

  // Frequency range. cava refuses a config whose lower cutoff is not below the
  // higher one, so keep at least 100 Hz between them instead of letting cava
  // exit and restart in a loop.
  readonly property int lowFreq: clampInt(setting("lowFreq", 50), 20, 19900)
  readonly property int highFreq: Math.max(lowFreq + 100, clampInt(setting("highFreq", 10000), 120, 20000))
  readonly property int sensitivity: clampInt(setting("sensitivity", 100), 10, 5000)
  readonly property bool autoSensitivity: isOn(setting("autoSensitivity", "On"))

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

  property var levels: []
  property int silentFrames: 0
  readonly property bool silent: silentFrames >= framerate
  property bool available: true
  property bool restarting: false

  function clampInt(value, min, max) {
    var n = Math.round(Number(value))
    if (!isFinite(n)) n = min
    return Math.max(min, Math.min(max, n))
  }

  function isOn(value) {
    return value === true || String(value).toLowerCase() === "on" || String(value) === "true"
  }

  // Written to cava through process substitution, so no temp files are left
  // behind. sleep_timer lets cava idle when the output is silent.
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
    "source=auto",
    "[output]",
    "method=raw",
    "raw_target=/dev/stdout",
    "data_format=ascii",
    "ascii_max_range=100",
    "bar_delimiter=59",
    "frame_delimiter=10",
    "channels=mono",
    "[smoothing]",
    "noise_reduction=77",
    ""
  ].join("\n")

  function parseFrame(line) {
    var parts = line.split(";")
    var next = []
    var loud = false
    for (var i = 0; i < barCount; i++) {
      var v = Number(parts[i]) / 100
      if (!isFinite(v)) v = 0
      v = Math.max(0, Math.min(1, v))
      if (v > 0) loud = true
      next.push(v)
    }
    levels = next
    silentFrames = loud ? 0 : Math.min(silentFrames + 1, framerate)
  }

  // A running Process can't be relaunched in place: stop it and start the new
  // one from onExited, so the old exit can't be mistaken for a crash.
  function restartCava() {
    levels = []
    silentFrames = framerate
    restartTimer.stop()
    if (cava.running) {
      restarting = true
      cava.running = false
    } else {
      startTimer.restart()
    }
  }

  onCavaConfigChanged: restartCava()

  visible: available && !(hideWhenSilent && silent)
  implicitWidth: vertical ? barSize : content.width + padding * 2
  implicitHeight: vertical ? content.height + padding * 2 : barSize

  Process {
    id: cava
    command: ["bash", "-c", "command -v cava >/dev/null || exit 127; exec cava -p <(printf '%s' \"$0\")", root.cavaConfig]
    stdout: SplitParser {
      onRead: function(line) { root.parseFrame(line) }
    }

    onExited: function(exitCode) {
      if (exitCode === 127) {
        root.available = false
        console.warn("syzyf97.cava: cava is not installed")
        return
      }
      if (root.restarting) {
        root.restarting = false
        startTimer.restart()
        return
      }
      // cava can drop out when PipeWire restarts; come back shortly after.
      root.silentFrames = root.framerate
      restartTimer.restart()
    }
  }

  // Settings are injected right after the widget is created, so the first
  // start waits a moment instead of launching cava with the defaults.
  Timer {
    id: startTimer
    interval: 100
    running: true
    onTriggered: if (!cava.running) cava.running = true
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: if (!cava.running) cava.running = true
  }

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
      if (containsMouse) root.bar.showTooltip(root, "Cava")
      else root.bar.hideTooltip(root)
    }
  }
}
