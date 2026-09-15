pragma Singleton
import QtQuick
import Quickshell

// Shares cava processes between widgets. Every widget copy on every monitor
// that ends up with the same cava config (same bars, framerate, range, source
// and bar height) reads from one process instead of starting its own.
Singleton {
  id: hub

  property var channels: ({})

  Component {
    id: channelComponent
    CavaChannel {}
  }

  function acquire(config, cavaSource) {
    var channel = channels[config]
    if (!channel) {
      channel = channelComponent.createObject(hub, { config: config, cavaSource: cavaSource })
      if (!channel) return null
      channels[config] = channel
    }
    channel.subscribers++
    console.debug("syzyf97.cava: widget subscribed to " + cavaSource + ", subscribers " + channel.subscribers)
    return channel
  }

  function release(channel) {
    if (!channel) return
    channel.subscribers = Math.max(0, channel.subscribers - 1)
    console.debug("syzyf97.cava: widget unsubscribed from " + channel.cavaSource + ", subscribers " + channel.subscribers)
    if (channel.subscribers > 0) return
    // Keep an idle channel briefly: a settings change or a monitor hotplug
    // usually releases and re-acquires the same config right away.
    reapTimer.restart()
  }

  Timer {
    id: reapTimer
    interval: 10000
    onTriggered: {
      var keep = {}
      for (var key in hub.channels) {
        var channel = hub.channels[key]
        if (channel && channel.subscribers > 0) keep[key] = channel
        else if (channel) channel.destroy()
      }
      hub.channels = keep
    }
  }
}
