import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
  id: root

  property var shell: null
  property bool awakeEnabled: true
  property bool stateLoaded: false
  property bool inhibitorRunning: false
  property bool idleDisabledByMedia: false

  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/media-awake/enabled"
  readonly property string idleStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property bool mediaPlaying: {
    for (var i = 0; i < players.length; i++) {
      if (players[i] && players[i].isPlaying) return true
    }
    return false
  }
  readonly property bool inhibiting: awakeEnabled && mediaPlaying && inhibitorRunning

  function statusJson() {
    return JSON.stringify({
      enabled: root.awakeEnabled,
      mediaPlaying: root.mediaPlaying,
      inhibiting: root.inhibiting,
      playerCount: root.players.length
    })
  }

  function persist(value) {
    stateWriter.command = [
      "bash", "-lc",
      "mkdir -p \"$(dirname \"$HOME/.local/state/omarchy/media-awake/enabled\")\"; " +
      (value
        ? "printf enabled > \"$HOME/.local/state/omarchy/media-awake/enabled\""
        : "rm -f \"$HOME/.local/state/omarchy/media-awake/enabled\"")
    ]
    stateWriter.running = true
  }

  function setEnabled(value, save) {
    root.awakeEnabled = !!value
    if (save) root.persist(root.awakeEnabled)
    root.updateInhibitor()
    root.updateIdleService()
    return root.awakeEnabled ? "enabled" : "disabled"
  }

  function toggle() {
    return root.setEnabled(!root.awakeEnabled, true)
  }

  function updateInhibitor() {
    var shouldInhibit = root.awakeEnabled && root.mediaPlaying
    if (shouldInhibit && !inhibitor.running) {
      inhibitor.command = [
        "systemd-inhibit",
        "--what=idle:sleep",
        "--who=Omarchy Media Awake",
        "--why=Media is playing",
        "--mode=block",
        "sleep", "infinity"
      ]
      inhibitor.running = true
    } else if (!shouldInhibit && inhibitor.running) {
      inhibitor.running = false
    }
    root.inhibitorRunning = inhibitor.running
  }

  function updateIdleService() {
    var shouldDisableIdle = root.awakeEnabled && root.mediaPlaying
    if (shouldDisableIdle && !root.idleDisabledByMedia) {
      if (!idleStateWriter.running) {
        idleStateWriter.command = [
          "bash", "-lc",
          "mkdir -p \"$HOME/.local/state/omarchy/indicators\"; " +
          "if [ -e \"$HOME/.local/state/omarchy/indicators/stay-awake\" ]; then " +
          "printf existing; else touch \"$HOME/.local/state/omarchy/indicators/stay-awake\"; printf created; fi"
        ]
        idleStateWriter.running = true
      }
    } else if (!shouldDisableIdle && root.idleDisabledByMedia) {
      if (!idleStateWriter.running) {
        idleStateWriter.command = [
          "bash", "-lc",
          "rm -f \"$HOME/.local/state/omarchy/indicators/stay-awake\""
        ]
        idleStateWriter.running = true
        root.idleDisabledByMedia = false
      }
    }
  }

  Process {
    id: stateProbe
    command: [
      "bash", "-lc",
      "if [ -f \"$HOME/.local/state/omarchy/media-awake/enabled\" ]; then cat \"$HOME/.local/state/omarchy/media-awake/enabled\"; else echo enabled; fi"
    ]
    stdout: SplitParser {
      onRead: function(line) {
        root.setEnabled(String(line).trim() !== "disabled", false)
        root.stateLoaded = true
      }
    }
  }

  Process {
    id: stateWriter
  }

  Process {
    id: inhibitor
    onRunningChanged: root.inhibitorRunning = inhibitor.running
    onExited: function() {
      root.inhibitorRunning = false
      Qt.callLater(root.updateInhibitor)
    }
  }

  Process {
    id: idleStateWriter
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).trim() === "created") root.idleDisabledByMedia = true
      }
    }
  }

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.updateInhibitor() }
    }
  }

  IpcHandler {
    target: "media-awake"

    function status(): string {
      return root.statusJson()
    }

    function enable(): string {
      return root.setEnabled(true, true)
    }

    function disable(): string {
      return root.setEnabled(false, true)
    }

    function toggle(): string {
      return root.toggle()
    }
  }

  Component.onCompleted: {
    stateProbe.running = true
  }
  onMediaPlayingChanged: {
    root.updateInhibitor()
    root.updateIdleService()
  }
  onAwakeEnabledChanged: {
    root.updateInhibitor()
    root.updateIdleService()
  }
}
