# Notes for working in this repo

## What this is

A project-context overlay on top of Hyprland + Waybar. Each context (`a` through `e`) owns 10 workspaces and 1 scratchpad. Switching contexts swaps which workspaces are visible. Designed for Omarchy but should work with vanilla Hyprland.

## Core invariant: waybar config is static

The waybar config (`templates/waybar.config.jsonc`) **never changes after install**. Context switching does not regenerate it, does not signal it, does not restart waybar. Every previous attempt at "reload waybar on switch" caused visible flicker (layer-surface release + window resize). The current design avoids this entirely.

When making changes, do not introduce anything that requires waybar to reload its JSON config on context switch. CSS reload via `reload_style_on_change: true` is fine; SIGUSR2 reload is not.

## How context switching actually works

Workspaces are **always** named `1`–`10` for the active context. Hidden contexts' workspaces are named `_a-1`, `_b-2`, etc.

`hyprwayspaces-switch` swaps contexts by **moving windows** between workspaces (via `hyprctl dispatch movetoworkspacesilent`), not by renaming workspaces. Reason: `renameworkspace` events fire in waybar but waybar doesn't re-run its `ignore-workspaces` filter on rename — so a workspace admitted as `1` stays admitted after being renamed to `_a-1`. Moving windows means the new `_a-1` workspace is created fresh, hits the ignore filter at creation, and is hidden correctly.

The `^_.*` `ignore-workspaces` regex hides all underscore-prefixed workspaces. The state file `generated/current-context` is updated and the `custom/workspace-context` waybar module gets a `SIGRTMIN+11` signal to re-exec immediately (the module polls the state file with `cat`).

## Workspace name forms

- **User-facing slot syntax** (script args): `a-1`, `b-10`, `c-s` (`s` = scratchpad)
- **Hyprland workspace name** (active context):  bare `1`, `2`, … `10`
- **Hyprland workspace name** (hidden context):  `_a-1`, `_b-10`, …
- **Hyprland workspace name** (scratchpad, any context): `special:scratch-<ctx>`

Use `slot_to_bare` helper logic (present in `move`, `launch`, `swap`) to translate. Whether a slot resolves to a bare numeric or underscore-prefixed name depends on the current context, read from `generated/current-context`.

## Layout

```
bin/                          atomic commands, symlinked into ~/.config/hypr/scripts/
├── hws                          short dispatcher; symlinked to ~/.local/bin/
├── hyprwayspaces-switch       up | down | a..e
├── hyprwayspaces-move           <source> <dest>...   source = slot or class:/title: selector
├── hyprwayspaces-launch         [--if-empty] <slot>... -- <cmd>
├── hyprwayspaces-launch-terms   <dir-or-query> <count> [<ctx>]   bulk terminals with CWD
├── hyprwayspaces-load-tabs      <project> <slot>   open saved Firefox tabs in a slot
├── hyprwayspaces-swap           <slot> <slot>   or   <ctx-letter> <ctx-letter>
├── hyprwayspaces-scratchpad-toggle    bound to SUPER+S
└── hyprwayspaces-scratchpad-move      bound to SUPER+ALT+S

hypr/hyprwayspaces-keys.conf  static hyprland keybinds, sourced from hyprland.conf
templates/waybar.config.jsonc symlinked into ~/.config/waybar/config.jsonc, never regenerated
generated/                    runtime state (gitignored except .gitkeep)
└── current-context              single character a..e
install.sh                    creates symlinks; idempotent
```

The `hws <verb>` dispatcher just exec's `hyprwayspaces-<verb>` — use it interchangeably.

## Slot iteration is shell, not a DSL

The commands are variadic. Use bash brace expansion for ranges:

```sh
hws move class:firefox {a..e}-s    # claim → 5 scratchpads
hws launch a-{1..4} -- alacritty   # 4 spawns, one per workspace (one-per-slot mode)
for s in {a,c,e}-1; do hws launch --if-empty $s -- foot; done
```

`hyprwayspaces-launch` has two modes by slot count:

- **1 slot**: `hyprctl dispatch exec '[workspace name:<slot> silent] cmd'`. `--if-empty` checks for any window in that slot first.
- **N slots**: snapshot existing addresses, `setsid -f` the command, poll new addresses, distribute round-robin. Stops on quiescent window (default 2s without new windows) or hard `--wait` deadline (default 8s).

`hyprwayspaces-move`'s source can be a slot OR a selector like `class:Firefox`, `title:lazydocker`. Multiple destinations distribute round-robin.

`hyprwayspaces-swap` has two forms: two slots (windows-only swap) or two bare letters (swap every workspace 1..10 and the scratchpad of the two contexts in one atomic snapshot-then-move pass).

## Firefox tab-saver extension

`firefox-extension/` is a tiny WebExtension. The user clicks the toolbar icon on a Firefox window, types a project name, and that window's tabs are dumped to `~/.config/hyprwayspaces/projects/<name>.{json,urls}` via native messaging. The window keeps the mark across reload via `sessions.setWindowValue`. Subsequent tab/URL changes auto-dump (debounced 1.5s).

`native-host/hyprwayspaces-tab-saver` is the helper (Python, length-prefixed JSON over stdin/stdout per Mozilla's protocol). `install.sh` generates `~/.mozilla/native-messaging-hosts/hyprwayspaces.json` to register it.

The `.urls` file is one URL per line; `hyprwayspaces-load-tabs <project> <slot>` reads it and runs `hyprwayspaces-launch <slot> -- firefox --new-window URL1 URL2 ...`.

For permanent Firefox use the extension needs to be signed (Developer Edition / Nightly / AMO unlisted signing). Loading via about:debugging "Load Temporary Add-on" works per-session for testing.

## Hyprland config requirements

Several hyprland settings interact materially with how context switching looks and feels. A reference `hypr/looknfeel.example.conf` is committed; merge the bits you care about into `~/.config/hypr/looknfeel.conf`.

- **`master:new_status = slave`** — *required*. With the default `master`, every `movetoworkspacesilent` makes the moved window the new master, which inverts master/slave on each restore (terminals visibly swap). With `slave`, the first moved window stays master and subsequent moves slot in below it. The switcher sorts clients by `(y, x)` ascending and moves master first to take advantage of this.
- **`cursor:warp_on_change_workspace = 1`** — recommended. Cursor jumps to the focused window on workspace change, so focus-follow-mouse doesn't snatch focus onto a sibling under the pointer.
- **`input:follow_mouse = 1` / `input:mouse_refocus = false`** — recommended; standard focus-follows-mouse without re-asserting focus on every motion.
- **`binds:workspace_center_on = 1`** — keeps focus on the visually-centered window when entering a workspace.

## Touchpad gestures

3-finger swipes are wired in `hypr/hyprwayspaces-keys.conf` via hyprland 0.54's `gesture` directive with the `dispatcher` action (NOT `bindgesture`, NOT `gesture = ... exec ...` — only `gesture = N, DIR, dispatcher, DISPATCHER, ARGS`):

- up / down → `hyprwayspaces-switch up` / `down`
- left / right → `hyprwayspaces-switch left` / `right` (clamps at 1..10)

## Special workspaces (scratchpads)

`renameworkspace` does NOT work on special workspaces in Hyprland — verified empirically; the dispatcher returns ok but does nothing useful. Per-context scratchpads are kept alive as separate `special:scratch-a`, `special:scratch-b`, etc. The `SUPER+S` keybind exec's `hyprwayspaces-scratchpad-toggle` which reads the state file and toggles the right one.

## Things that have been tried and rejected

- **Restarting waybar on context switch** — causes flicker.
- **SIGUSR2 reload** — also causes layer-surface release flicker.
- **Per-context generated waybar config** (`__CTX__` template substitution) — requires reload, see above.
- **`renameworkspace`-based context switching** — waybar doesn't re-filter on rename; renamed workspaces stay visible.
- **Multi-bar waybar with per-context bars** — investigated, no clean way to toggle individual bar visibility without restart.
- **CSS-only filtering by workspace name** — waybar workspace buttons only get `.active/.empty/.persistent/.urgent/.special/.visible/.hosting-monitor` classes; no per-name selectors are exposed.

If considering any of the above, search the conversation history first — there's likely a reason it was discarded.

## Style

- Bash scripts use `set -euo pipefail` and `mapfile`/`while read` over command substitution where possible.
- All notifications go through `notify-send -u low` with title `"hyprwayspaces"` or `"hyprwayspaces-<verb>"`.
- Helper functions (`slot_to_bare`, `dispatch_form`) are duplicated across the verb scripts; if a 4th appears, factor into a shared `lib/` source file.
