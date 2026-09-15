import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// One cava process, shared by every widget that asks for the same config.
//
// cava only runs while someone is subscribed and, when it listens to an
// output, while something is actually playing into that output. Frames that
// are identical to the previous one are dropped here, so subscribers only
// repaint when the bars really move.
Scope {
  id: channel

  required property string config
  // cava's source value: "auto", "auto_input", "<sink>.monitor" or a node name.
  required property string cavaSource

  property int subscribers: 0
  property bool available: true
  readonly property bool running: cava.running

  signal frame(string line)
  signal stopped()

  // --- Is anything playing? ------------------------------------------------
  //
  // Output sources are recorded through a sink monitor. An application stream
  // linked into that sink with an active link means audio is flowing; a paused
  // player keeps its link but moves it to "paused". Microphones and unknown
  // nodes have no such signal, so cava keeps running there and relies on its
  // own sleep_timer.
  readonly property bool watchesOutput: cavaSource === "auto" || /\.monitor$/.test(cavaSource)
  readonly property var sinkNode: {
    if (!watchesOutput) return null
    if (cavaSource === "auto") return Pipewire.defaultAudioSink
    var name = cavaSource.replace(/\.monitor$/, "")
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (node && node.isSink && !node.isStream && String(node.name) === name) return node
    }
    return null
  }

  PwNodeLinkTracker {
    id: links
    node: channel.sinkNode
  }
  // Link state is only kept up to date for tracked objects.
  PwObjectTracker { objects: links.linkGroups || [] }

  readonly property bool playing: {
    // No sink to watch (PipeWire not ready yet, unknown device): never block
    // cava on a signal that will not come.
    if (!watchesOutput || !sinkNode) return true
    var groups = links.linkGroups || []
    for (var i = 0; i < groups.length; i++) {
      var group = groups[i]
      if (group && group.target === sinkNode && group.source && group.source.isStream
          && group.state === PwLinkState.Active) return true
    }
    return false
  }

  // Keep cava around for a few seconds after playback stops, so skipping a
  // track or a short pause does not restart it.
  Timer {
    id: lingerTimer
    interval: 4000
  }

  onPlayingChanged: if (!playing) lingerTimer.restart()

  readonly property bool wanted: available && subscribers > 0 && (playing || lingerTimer.running)

  // --- Process ---------------------------------------------------------------

  property string lastLine: ""
  property bool crashed: false

  function sync() {
    if (wanted && !cava.running && !crashed) cava.running = true
    else if (!wanted && cava.running) cava.running = false
  }

  onWantedChanged: Qt.callLater(sync)
  Component.onCompleted: Qt.callLater(sync)

  Process {
    id: cava
    // The config goes in through process substitution: no temp files.
    command: ["bash", "-c", "command -v cava >/dev/null || exit 127; exec cava -p <(printf '%s' \"$0\")", channel.config]

    stdout: SplitParser {
      onRead: function(line) {
        if (line === channel.lastLine) return
        channel.lastLine = line
        channel.frame(line)
      }
    }

    onRunningChanged: {
      console.debug("syzyf97.cava: cava " + (running ? "started" : "stopped") + " for " + channel.cavaSource
        + " (subscribers " + channel.subscribers + ", playing " + channel.playing + ")")
      if (running) return
      channel.lastLine = ""
      channel.stopped()
    }

    onExited: function(exitCode) {
      if (exitCode === 127) {
        channel.available = false
        console.warn("syzyf97.cava: cava is not installed")
        return
      }
      if (!channel.wanted) return
      // cava can drop out when PipeWire restarts; come back shortly after.
      channel.crashed = true
      retryTimer.restart()
    }
  }

  Timer {
    id: retryTimer
    interval: 3000
    onTriggered: {
      channel.crashed = false
      channel.sync()
    }
  }
}
