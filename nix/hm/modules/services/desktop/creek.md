# `services.creek` - Module Documentation

A Home Manager module for **creek**, a minimalist status bar for the [River](https://codeberg.org/river/river) compositor. The module manages creek's systemd user service and exposes its configuration options declaratively.

---

## Options

### `services.creek.enable`
**Type:** `boolean` | **Default:** `false`

Enables the creek service and its systemd unit.

---

### `services.creek.package`
**Type:** `package` | **Default:** `pkgs.creek`

The creek package to use.

---

### `services.creek.settings`

**Type:** `submodule` | **Default:** `{}`

Configuration for creek. All options are optional — omitting `settings` entirely falls back to creek's own defaults.

| Option                     | Type   | Default | Description   |                                  |
|----------------------------|--------|---------|---------------|----------------------------------|
| `font-name`                | `str \ | null`   | `"monospace"` | Font family name                 |
| `font-size`                | `int \ | null`   | `10`          | Font size (in points)            |
| `size`                     | `int \ | null`   | `15`          | Bar height (in pixels)           |
| `foreground-color`         | `hex \ | null`   | `"#b8b8b8"`   | Default text color               |
| `background-color`         | `hex \ | null`   | `"#282828"`   | Default background color         |
| `focused-foreground-color` | `hex \ | null`   | `"#181818"`   | Text color on focused tags       |
| `focused-background-color` | `hex \ | null`   | `"#7cafc2"`   | Background color on focused tags |

Hex color values use the custom `lib.extra.types.colors.hex` type, which validates and converts hex strings for use as binary color arguments.

---

## Example Configuration

```nix
services.creek = {
  enable = true;

  settings = {
    font-name = "Tamsyn";
    font-size = 15;
    size = 17;

    foreground-color         = "#aaaaaa";
    background-color         = "#000000";
    focused-foreground-color = "#ffffff";
    focused-background-color = "#000000";
  };
};
```

---

## Notes

**Systemd service** — The module creates a `systemd.user.services.creek` unit that:
- Starts after `graphical-session.target` and is bound to its lifetime
- Only launches if `WAYLAND_DISPLAY` is set in the environment (`ConditionEnvironment`)
- Restarts automatically on failure (`Restart = "on-failure"`)
- Runs inside `session-graphical.slice`

**Status feed** — Creek requires a stream of text piped to stdin to display as the bar's status. The module satisfies this by wrapping creek in a shell script that continuously pipes the output of `date`, refreshing every second:

```bash
while date; do
  sleep 1;
done | creek [args...]
```

**Argument construction** — If `settings` is non-empty, creek is launched with explicit flags derived from your config:
- `-fn <name>:size=<size>` — font
- `-hg <size>` — bar height
- `-nf/-nb` — normal foreground/background
- `-ff/-fb` — focused foreground/background

Hex colors are converted to the binary format creek expects via `lib.extra.colors.hexToBin`. If `settings = {}`, no flags are passed and creek uses its own built-in defaults.