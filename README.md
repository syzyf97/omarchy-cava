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
omarchy bar set syzyf97.cava lowFreq 40 --json
omarchy bar set syzyf97.cava sensitivity 800 --json
omarchy bar set syzyf97.cava autoSensitivity Off
```

Changes apply immediately.

### Checking the current settings

`bin/omarchy-cava-settings` prints the settings the widget is using: defaults merged with your `shell.json` entry and clamped to the same limits as the widget. Values that were clamped or normalized are marked, and unknown keys are listed.

```bash
ln -s ~/.config/omarchy/plugins/syzyf97.cava/bin/omarchy-cava-settings ~/.local/bin/
omarchy-cava-settings          # table
omarchy-cava-settings --json   # effective settings as JSON
```

The widget works on vertical (left/right) bars too.

## Remove

```bash
omarchy plugin remove syzyf97.cava
```

## License

MIT
