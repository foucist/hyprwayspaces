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

link "$REPO/bin/hyprwayspaces-switch"            "$HOME/.config/hypr/scripts/hyprwayspaces-switch"
link "$REPO/bin/hyprwayspaces-scratchpad-toggle"   "$HOME/.config/hypr/scripts/hyprwayspaces-scratchpad-toggle"
link "$REPO/bin/hyprwayspaces-scratchpad-move"     "$HOME/.config/hypr/scripts/hyprwayspaces-scratchpad-move"
link "$REPO/bin/hyprwayspaces-move"                "$HOME/.config/hypr/scripts/hyprwayspaces-move"
link "$REPO/bin/hyprwayspaces-launch"              "$HOME/.config/hypr/scripts/hyprwayspaces-launch"
link "$REPO/bin/hyprwayspaces-swap"                "$HOME/.config/hypr/scripts/hyprwayspaces-swap"
link "$REPO/bin/hyprwayspaces-launch-terms"        "$HOME/.config/hypr/scripts/hyprwayspaces-launch-terms"
link "$REPO/bin/hyprwayspaces-load-tabs"           "$HOME/.config/hypr/scripts/hyprwayspaces-load-tabs"
link "$REPO/bin/hyprwayspaces-ws-step"             "$HOME/.config/hypr/scripts/hyprwayspaces-ws-step"
link "$REPO/bin/hws"                               "$HOME/.local/bin/hws"
link "$REPO/hypr/hyprwayspaces-keys.conf"          "$HOME/.config/hypr/hyprwayspaces-keys.conf"
link "$REPO/templates/waybar.config.jsonc"         "$HOME/.config/waybar/config.jsonc"

[[ -f "$REPO/generated/current-context" ]] || echo -n "a" > "$REPO/generated/current-context"

# Register the Firefox native messaging host (for the tab-saver extension).
NATIVE_HOST_DIR="$HOME/.mozilla/native-messaging-hosts"
mkdir -p "$NATIVE_HOST_DIR"
host_manifest="$NATIVE_HOST_DIR/hyprwayspaces.json"
host_path="$REPO/native-host/hyprwayspaces-tab-saver"
sed "s|__HOST_PATH__|${host_path}|" "$REPO/native-host/manifest.template.json" > "$host_manifest"
chmod +x "$host_path"
echo "wrote $host_manifest"

cat <<EOF

Done. To finish setup:

1. Add this line to ~/.config/hypr/hyprland.conf (after bindings.conf):

       source = ~/.config/hypr/hyprwayspaces-keys.conf

   Optional, in ~/.config/hypr/autostart.conf:

       exec-once = ~/.config/hypr/scripts/hyprwayspaces-switch a

   Then reload hyprland and restart waybar once:

       hyprctl reload && omarchy-restart-waybar

2. Load the Firefox tab-saver extension (one-time, lasts for the Firefox session;
   for permanent use you need Developer Edition / Nightly, or self-sign via AMO):

   - Open Firefox, go to about:debugging#/runtime/this-firefox
   - Click "Load Temporary Add-on…"
   - Select: $REPO/firefox-extension/manifest.json

   Then click the toolbar icon on any Firefox window, type a project name
   (e.g. "fluency"), and hit save. Tab dumps go to:

       ~/.config/hyprwayspaces/projects/<name>.{json,urls}

   Restore later in any slot with:

       hws load-tabs fluency a-s
EOF
