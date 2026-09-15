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
{ "id": "syzyf97.cava", "bars": 10, "framerate": 30, "color": "foreground", "hideWhenSilent": "Off" }
```

| Key              | Default        | Meaning                                         |
|------------------|----------------|-------------------------------------------------|
| `bars`           | `10`           | Number of bars (4–32)                           |
| `framerate`      | `30`           | Frames per second (10–60)                       |
| `color`          | `"foreground"` | `"foreground"` or `"accent"` from the theme     |
| `hideWhenSilent` | `"Off"`        | `"On"` hides the widget while nothing is playing |

The widget works on vertical (left/right) bars too.

## Remove

```bash
omarchy plugin remove syzyf97.cava
```

## License

MIT
