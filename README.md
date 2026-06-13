# Screen Manager — Plugin for Noctalia

Gerencia monitores no **Niri** directly from the Noctalia shell bar. Mirror, enable/disable outputs, and manage your multi-monitor setup with a simple panel.

> **Requires:** [Noctalia](https://github.com/noctalia-dev/noctalia-qs) ≥ 3.6.0 · [Niri](https://github.com/YaLTeR/niri) compositor · [wl-mirror](https://github.com/Footpad/wl-mirror) (for mirroring)

---

## Features

- **Mirror** — duplicate one screen onto another using `wl-mirror`
- **Enable / Disable** — turn individual outputs on or off (with safety lock: cannot disable the last active screen)
- **Enable All** — turn on every connected display at once
- **Load Screens** — refresh the list of detected monitors
- **IPC support** — control everything via keybindings through the IPC interface

---

## Installation

### Manual

Clone this repository into your Noctalia plugins directory:

```bash
cd ~/.config/noctalia/plugins
git clone https://github.com/YOUR_USER/screen-manager.git screen-manager
```

Restart Noctalia and the plugin will appear in the plugin list.

### Dependencies

Make sure `wl-mirror` is installed for the mirror feature:

```bash
# Arch Linux
sudo pacman -S wl-mirror
```

---

## IPC Commands

You can bind keys to these IPC commands in your Niri config:

| Command | Description |
|---------|-------------|
| `target plugin:screen-manager` + `function toggle()` | Open/close the panel |
| `target plugin:screen-manager` + `function mirror()` | Mirror secondary onto primary |
| `target plugin:screen-manager` + `function stopMirror()` | Stop active mirroring |
| `target plugin:screen-manager` + `function disable()` | Disable the secondary output |
| `target plugin:screen-manager` + `function refresh()` | Refresh output list |

### Example keybinding (Niri)

```toml
binds {
    Mod+M { spawn "quickshell" "-c" "plugin:screen-manager" "mirror"; }
    Mod+Shift+M { spawn "quickshell" "-c" "plugin:screen-manager" "stopMirror"; }
}
```

---

## Panel

The panel shows a list of all connected monitors with:

- **Name**, **model** and **current resolution/refresh rate**
- **Enable / Disable** button per monitor
- **Mirror** button per monitor (starts mirroring that screen to the other; becomes **Stop Mirroring** when active)
- **Enable All** button at the bottom

The bar icon turns red when mirroring is active.

---

## Translations

| Language | Status |
|----------|--------|
| Português (pt) | Complete |
| English (en) | Complete |

To add a new language, create a file in `i18n/<code>.json` following the structure of `en.json`.

---

## License

MIT
