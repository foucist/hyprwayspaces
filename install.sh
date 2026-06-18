#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.config/hypr/scripts" "$HOME/.config/waybar" "$HOME/.local/bin" "$REPO/generated"

link() {
    local src="$1" dst="$2"
    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" == "$src" ]]; then
            echo "ok    $dst"
        else
            echo "exists $dst (different symlink; remove manually if you want to relink)"
        fi
        return
    fi
    if [[ -e "$dst" ]]; then
        mv "$dst" "$dst.bak.$(date +%s)"
        echo "backup $dst (original backed up)"
    fi
    ln -s "$src" "$dst"
    echo "link  $dst -> $src"
}

link "$REPO/bin/hyprwayspaces-switcher"            "$HOME/.config/hypr/scripts/hyprwayspaces-switcher"
link "$REPO/bin/hyprwayspaces-scratchpad-toggle"   "$HOME/.config/hypr/scripts/hyprwayspaces-scratchpad-toggle"
link "$REPO/bin/hyprwayspaces-scratchpad-move"     "$HOME/.config/hypr/scripts/hyprwayspaces-scratchpad-move"
link "$REPO/bin/hyprwayspaces-move"                "$HOME/.config/hypr/scripts/hyprwayspaces-move"
link "$REPO/bin/hyprwayspaces-launch"              "$HOME/.config/hypr/scripts/hyprwayspaces-launch"
link "$REPO/bin/hyprwayspaces-swap"                "$HOME/.config/hypr/scripts/hyprwayspaces-swap"
link "$REPO/bin/hyprwayspaces-launch-terms"        "$HOME/.config/hypr/scripts/hyprwayspaces-launch-terms"
link "$REPO/bin/hws"                               "$HOME/.local/bin/hws"
link "$REPO/hypr/hyprwayspaces-keys.conf"          "$HOME/.config/hypr/hyprwayspaces-keys.conf"
link "$REPO/templates/waybar.config.jsonc"         "$HOME/.config/waybar/config.jsonc"

[[ -f "$REPO/generated/current-context" ]] || echo -n "a" > "$REPO/generated/current-context"

cat <<EOF

Done. To finish setup, add this line to ~/.config/hypr/hyprland.conf:

    source = ~/.config/hypr/hyprwayspaces-keys.conf

(Place it after your existing 'source = ~/.config/hypr/bindings.conf'.)

Optional, in ~/.config/hypr/autostart.conf:

    exec-once = ~/.config/hypr/scripts/hyprwayspaces-switcher a

Then reload hyprland and restart waybar once:

    hyprctl reload && omarchy-restart-waybar

After that, context switches via SUPER ALT UP/DOWN never touch waybar again.
EOF
