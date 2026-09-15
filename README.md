# omarchy-cava

A small audio visualizer for the Omarchy bar, powered by [cava](https://github.com/karlstav/cava).
The bars use the bar foreground color of the current theme (or its accent), so the widget follows theme switches.

![preview](preview.png)

## Requirements

- Omarchy 4 shell (`omarchy-shell`)
- `cava` built with PipeWire input (`sudo pacman -S cava`)

The widget runs one `cava` process in raw output mode per bar instance (one per monitor). cava reads the default PipeWire output monitor, so the visualizer shows whatever is playing. No files are written and nothing runs as root.

## Install

```bash
omarchy plugin add https://github.com/syzyf97/omarchy-cava.git --enable
```

The widget lands in the right section of the bar. Move it with:

```bash
omarchy bar move syzyf97.cava --section center
```

## Usage

- The bars move while audio is playing and dim when it is silent.
- Left click opens full-screen cava in a terminal.

## Configuration

Settings go inline on the widget entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "syzyf97.cava",
  "audioSource": "output",
  "bars": 10,
  "framerate": 30,
  "lowFreq": 50,
  "highFreq": 10000,
  "sensitivity": 100,
  "autoSensitivity": "On",
  "color": "foreground",
  "hideWhenSilent": "Off"
}
```

| Key              | Default        | Meaning                                         |
|------------------|----------------|-------------------------------------------------|
| `audioSource`    | `"output"`     | `"output"` (whatever is playing), `"input"` (default microphone), or a PipeWire device name |
| `bars`           | `10`           | Number of bars (4–32)                           |
| `framerate`      | `30`           | Frames per second (10–60)                       |
| `lowFreq`        | `50`           | Lowest frequency shown, in Hz (20–19900)        |
| `highFreq`       | `10000`        | Highest frequency shown, in Hz (120–20000); kept at least 100 Hz above `lowFreq` |
| `sensitivity`    | `100`          | Bar height in percent (10–5000). With auto sensitivity off, quiet music usually needs 500–2000 |
| `autoSensitivity`| `"On"`         | `"On"` lets cava adapt to the volume; `sensitivity` is then only the starting value |
| `color`          | `"foreground"` | `"foreground"` or `"accent"` from the theme     |
| `hideWhenSilent` | `"Off"`        | `"On"` hides the widget while nothing is playing |

Or from the command line (numbers need `--json`):

```bash
omarchy bar set syzyf97.cava audioSource input
omarchy bar set syzyf97.cava lowFreq 40 --json
omarchy bar set syzyf97.cava sensitivity 800 --json
omarchy bar set syzyf97.cava autoSensitivity Off
```

Changes apply immediately.

### Checking the current settings

`bin/omarchy-cava-settings` prints the settings the widget is using: defaults merged with your `shell.json` entry and clamped to the same limits as the widget. Values that were clamped or normalized are marked, and unknown keys are listed.

```bash
ln -s ~/.config/omarchy/plugins/syzyf97.cava/bin/omarchy-cava-settings ~/.local/bin/
omarchy-cava-settings            # table
omarchy-cava-settings --help     # every setting with its allowed values and examples
omarchy-cava-settings --sources  # audio devices for audioSource
omarchy-cava-settings --json     # section, index and settings of each widget as JSON
```

### Audio source

`"output"` and `"input"` follow the system defaults, so switching speakers or microphones in the audio panel moves the visualizer with them. To pin a specific device, use its PipeWire name:

```bash
omarchy-cava-settings --sources
omarchy bar set syzyf97.cava audioSource alsa_input.pci-0000_08_00.6.analog-stereo
```

An output device name is recorded through its monitor automatically. If the named device does not exist, cava falls back to the default microphone; `omarchy-cava-settings` flags that. While the visualizer listens to a microphone, the device is in use, so microphone indicators show it as active.

The key is `audioSource`, not `source`: the bar reserves `source`, `type` and `exec` for custom user modules.

### More than one visualizer

The widget can sit on the bar more than once, each copy with its own settings (for example a bass-only one next to the full range). `omarchy plugin enable` and `omarchy bar put` never add a second copy, so add the entry to `bar.layout` in `~/.config/omarchy/shell.json` yourself:

```json
"right": [
  { "id": "syzyf97.cava", "bars": 6, "lowFreq": 20, "highFreq": 250 },
  { "id": "syzyf97.cava", "bars": 16, "color": "accent", "audioSource": "input" }
]
```

With several copies, pick one by its section and index (counted from 0 among all widgets in that section) when changing a setting. `omarchy-cava-settings` prints the right flags for each copy:

```bash
omarchy bar set syzyf97.cava bars 8 --json --from-section right --from-index 0
```

Every copy runs its own cava process.

The widget works on vertical (left/right) bars too.

## Remove

```bash
omarchy plugin remove syzyf97.cava
```

## License

MIT
