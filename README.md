# hyprwayspaces

Project-context workspaces for Hyprland + Waybar with **zero waybar reloads** on context switch.

Each context (`a` through `e`) owns 10 workspaces and 1 scratchpad. Switching contexts hides the current set and reveals the target set without reloading Waybar, so there's no flicker.

```
context a:   1, 2, 3, ..., 10   scratch-a
context b:   1, 2, 3, ..., 10   scratch-b
...
```

Only one context's workspaces are visible at a time. Hidden contexts use `_a-1`, `_a-2`, etc. workspace names and are filtered from Waybar with a `^_` ignore pattern.

## Install

```sh
./install.sh
```

Add the one printed source line to `~/.config/hypr/hyprland.conf`, then reload.

## Keybinds

- `SUPER 1-0` — switch to workspace 1-10 within current context
- `SUPER SHIFT 1-0` — move window to workspace
- `SUPER SHIFT ALT 1-0` — move window silently
- `SUPER S` — toggle context-scoped scratchpad
- `SUPER ALT S` — move window to scratchpad
- `SUPER ALT UP/DOWN` — cycle contexts (capped at `a`/`e`, no wrap)

### Optional: 3-finger touchpad gestures (Hyprland 0.54+ only)

Source `~/.config/hypr/hyprwayspaces-gestures.conf` from `hyprland.conf` to enable:

- 3-finger vertical swipe → cycle contexts
- 3-finger horizontal swipe → step workspace within current context (clamps at 1 and 10)

The gesture syntax uses the `dispatcher` action keyword introduced in 0.54 — older versions won't accept it. If your reload fails, just don't source the file. The keybind features above don't depend on it.

## How it works

Workspaces in the active context are always named `1`–`10`. Hidden contexts are held on underscore-prefixed workspace names:

1. Moves windows from current `1`–`10` into `_<current>-1`–`_<current>-10`
2. Moves windows from `_<target>-N` back into `1`–`10`

Waybar's `hyprland/workspaces` module shows numeric names only; the `^_` ignore pattern hides everything else. Since the Waybar config is static during context switches, there is no flicker or resize.

The context indicator in waybar is a `custom/workspace-context` module that polls `generated/current-context` once per second.

The Waybar config also includes an invisible startup hook that reconciles workspace placeholders after Waybar itself restarts, such as during Omarchy theme changes.

## Atomic commands

For preset scripting and ad-hoc window juggling, two composable primitives:

**`hyprwayspaces-move <source> <dest> [<dest>...]`**
Move windows from a source to one or more slots. Multiple destinations → round-robin.

- Source can be a slot (`a-3`, `b-s`) or a selector (`class:firefox`, `title:lazydocker`).
- Destinations are slots.

```sh
hyprwayspaces-move a-3 b-3                       # slot → slot
hyprwayspaces-move class:firefox {a,b,c}-s       # distribute existing firefox → 3 scratchpads
hyprwayspaces-move title:lazydocker c-2          # claim by title
```

**`hyprwayspaces-launch [--if-empty] [--wait=Ns] <slot> [<slot>...] -- <command...>`**
Spawn a command into one slot, or spawn once and distribute new windows across N slots.

```sh
hyprwayspaces-launch a-1 -- alacritty                               # all windows → a-1
hyprwayspaces-launch --if-empty a-1 -- alacritty -e tmux            # idempotent
hyprwayspaces-launch {a..e}-s -- firefox                            # spawn once, restored windows → 5 scratchpads
```

Iteration is via shell — no DSL needed:
```sh
for s in a-{1..4}; do hyprwayspaces-launch --if-empty $s -- alacritty; done
```

## Files

- `bin/hyprwayspaces-switch` — main switcher (`up`/`down`/letter `a`–`e`)
- `bin/hyprwayspaces-move` — move windows between slots
- `bin/hyprwayspaces-launch` — spawn commands into slots
- `bin/hyprwayspaces-scratchpad-toggle` / `-scratchpad-move` — bound to SUPER+S / SUPER ALT+S
- `hypr/hyprwayspaces-keys.conf` — static keybinds (sourced from hyprland.conf)
- `hypr/hyprwayspaces-gestures.conf` — optional 3-finger gesture bindings; Hyprland 0.54+ only
- `hypr/looknfeel.example.conf` — reference for hyprland options hyprwayspaces benefits from (master/cursor/etc.)
- `templates/waybar.config.jsonc` — static waybar config (symlinked into ~/.config/waybar/)
- `bin/hyprwayspaces-waybar-ready` — invisible Waybar startup hook that reconciles Hyprland after Waybar reloads
- `generated/current-context` — single-letter state file
- `install.sh` — creates the symlinks

## Planned

- High-level YAML preset runner that calls `launch`/`move` for you. See `presets/workspace-presets.example.yaml`.
