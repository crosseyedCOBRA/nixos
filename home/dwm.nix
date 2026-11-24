# dwm's startup script (the autostart patch runs it) and its helper
# scripts: the quickshell bar's link to dwm, the keybinding sheet and the
# main menu. Keybindings, rules and patches are in the dwm repo itself
# (config.h).
{ pkgs, inputs, ... }:

let
  # dwm's state in the same tags.json format Awesome's rc.lua writes, so
  # the quickshell bar (../quickshell/shell.qml) works unchanged: per
  # monitor (keyed by output name) the 9 tags, the layout name and whether
  # the focused window is fullscreen (the bar hides then). Rewritten on
  # every dwm IPC event; reconnects after dwm restarts in place, and exits
  # once dwm is gone.
  dwmBarState = pkgs.writeShellApplication {
    name = "dwm-bar-state";
    runtimeInputs = with pkgs; [ jq xrandr procps ];
    text = ''
      out="$HOME/.cache/awesome/tags.json"
      mkdir -p "''${out%/*}"

      # {"x,y": "output name"}, from xrandr. dwm merges monitors at the same
      # position (the HDMI mirror), so the first listed (the primary) wins.
      outputs() {
        xrandr --listactivemonitors 2>/dev/null | awk '
          NR > 1 && match($3, /\+[0-9]+\+[0-9]+$/) {
            pos = substr($3, RSTART + 1); sub(/\+/, ",", pos)
            if (!(pos in seen)) { seen[pos] = 1; printf "%s\"%s\":\"%s\"", (n++ ? "," : ""), pos, $NF }
          }
          BEGIN { printf "{" } END { print "}" }'
      }

      dump() {
        local mons fs num id full
        mons=$(dwm-msg get_monitors 2>/dev/null) || return 0
        fs="{"
        while read -r num id; do
          full=false
          if [ "$id" != 0 ]; then
            full=$(dwm-msg get_dwm_client "$id" 2>/dev/null | jq '[.. | objects | .is_fullscreen? // empty] | any') || full=false
          fi
          fs="$fs\"$num\":$full,"
        done < <(jq -r '.[] | "\(.num) \(.clients.selected)"' <<<"$mons")
        fs="''${fs%,}}"
        jq -c --argjson outs "$(outputs)" --argjson fs "$fs" '
          def bit($mask; $i): (($mask / pow(2; $i)) | floor) % 2 == 1;
          map({
            key: ($outs["\(.monitor_geometry.x),\(.monitor_geometry.y)"] // "monitor\(.num)"),
            value: {
              tags: [range(9) as $i | {
                name: "\($i + 1)",
                focused: bit(.tag_state.selected; $i),
                urgent: bit(.tag_state.urgent; $i)
              }],
              # monocle shows its window count, "[3]"; the bar shows "max"
              layout: (.layout.symbol.current | if test("^\\[[0-9]+\\]$") then "max" else . end),
              fullscreen: ($fs["\(.num)"] // false)
            }
          }) | from_entries' <<<"$mons" > "$out" || true
      }

      while pgrep -x dwm >/dev/null; do
        dump
        dwm-msg subscribe tag_change_event layout_change_event client_focus_change_event \
            focused_state_change_event monitor_focus_change_event 2>/dev/null |
          jq --unbuffered -c . | while read -r _; do dump; done || true # ends when dwm restarts or quits
        sleep 1
      done
    '';
  };

  # Clicking a tag on the bar (awesome-view-tag.sh hands over to this in
  # dwm): focus that bar's monitor, then view the tag.
  # Usage: dwm-view-tag <output name> <tag name 1-9>
  dwmViewTag = pkgs.writeShellApplication {
    name = "dwm-view-tag";
    runtimeInputs = with pkgs; [ jq xrandr ];
    text = ''
      output=$1 tag=$2
      mons=$(dwm-msg get_monitors)
      pos=$(xrandr --listactivemonitors 2>/dev/null | awk -v o="$output" '
        $NF == o && match($3, /\+[0-9]+\+[0-9]+$/) { p = substr($3, RSTART + 1); sub(/\+/, ",", p); print p; exit }')
      read -r target sel count < <(jq -r --arg pos "$pos" '[
          ([.[] | select("\(.monitor_geometry.x),\(.monitor_geometry.y)" == $pos) | .num] | first // -1),
          ([.[] | select(.is_selected) | .num] | first),
          length
        ] | @tsv' <<<"$mons")
      # dwm's focusmon only steps to the next/previous monitor.
      if [ "$target" -ge 0 ]; then
        for ((i = 0; i < (target - sel + count) % count; i++)); do
          dwm-msg --ignore-reply run_command focusmon 1
        done
      fi
      dwm-msg --ignore-reply run_command view $((1 << (tag - 1)))
    '';
  };

  # Super+F1: the keybindings, read from the config.h dwm was built from.
  # Each key line's trailing comment is its description, and the section
  # comments inside keys[] are the headings.
  dwmKeys = pkgs.writeShellApplication {
    name = "dwm-keys";
    runtimeInputs = with pkgs; [ rofi ];
    text = ''
      awk '
        /^static const Key keys\[\] = \{/ { on = 1; next }
        on && /^\};/ { exit }
        on && /^\t\/\* .* \*\/$/ && !/modifier/ {
          h = $0; sub(/^\t\/\* /, "", h); sub(/ \*\/$/, "", h)
          printf "━━ %s ━━\n", h; next
        }
        on && /^\t\{.*\/\/ / {
          desc = $0; sub(/.*\/\/ /, "", desc)
          line = $0; sub(/^\t\{ */, "", line); split(line, f, ",")
          mods = f[1]; key = f[2]; gsub(/ /, "", mods); gsub(/ /, "", key)
          m = ""
          if (mods ~ /MODKEY/) m = m "Super+"
          if (mods ~ /ControlMask/) m = m "Ctrl+"
          if (mods ~ /Mod1Mask/) m = m "Alt+"
          if (mods ~ /ShiftMask/) m = m "Shift+"
          sub(/^XF86XK_/, "", key); sub(/^XK_/, "", key)
          if (length(key) == 1) key = toupper(key)
          else if (key == "space") key = "Space"
          printf "%-24s %s\n", m key, desc
        }
        END {
          print "━━ Tags ━━"
          printf "%-24s %s\n", "Super+1-9", "view a tag"
          printf "%-24s %s\n", "Super+Ctrl+1-9", "add a tag to the view"
          printf "%-24s %s\n", "Super+Shift+1-9", "move the window to a tag"
          printf "%-24s %s\n", "Super+Ctrl+Shift+1-9", "add the window to a tag"
          print "━━ Mouse ━━"
          printf "%-24s %s\n", "Super+drag", "move a window"
          printf "%-24s %s\n", "Super+right-drag", "resize a window"
          printf "%-24s %s\n", "Super+middle-click", "floating on/off"
          printf "%-24s %s\n", "Super+scroll", "previous/next tag"
          printf "%-24s %s\n", "right-click desktop", "main menu"
        }' ${inputs.dwm}/config.h |
        rofi -dmenu -i -no-custom -p "dwm keys" -font "JetBrainsMono Nerd Font 11" \
          -theme-str 'window { width: 46em; } listview { lines: 18; }' >/dev/null || true
    '';
  };

  # Super+Shift+W or right-clicking the desktop, like Awesome's main menu.
  dwmMenu = pkgs.writeShellApplication {
    name = "dwm-menu";
    runtimeInputs = with pkgs; [ rofi procps ];
    text = ''
      choice=$(printf '%s\n' "Apps" "Terminal" "Files" "Keybindings" "Wallpaper" \
          "Edit dwm config" "dwm manual" "Restart dwm" "Log out" "Power menu" |
        rofi -dmenu -i -no-custom -p dwm) || exit 0
      case $choice in
        "Apps") rofi -show drun -show-icons ;;
        "Terminal") alacritty ;;
        "Files") thunar ;;
        "Keybindings") dwm-keys ;;
        "Wallpaper") awesome-wallpaper-picker ;;
        "Edit dwm config") alacritty -e "''${EDITOR:-nano}" "$HOME/src/dwm/config.h" ;;
        "dwm manual") alacritty -e man dwm ;;
        "Restart dwm") pkill -HUP -x dwm ;;
        "Log out") dwm-msg run_command quit ;;
        "Power menu") power-menu ;;
      esac
    '';
  };
in
{
  # dwm runs this after it starts -- and again after every in-place
  # restart (Super+Ctrl+R, wallpaper changes), so the one-time setup only
  # happens once per login.
  xdg.dataFile."dwm/autostart.sh" = {
    executable = true;
    text = ''
      #!/bin/sh
      marker="''${XDG_RUNTIME_DIR:-/tmp}/dwm-autostart-''${XDG_SESSION_ID:-0}"
      [ -e "$marker" ] && exit 0
      touch "$marker"

      # Same monitor layout as Awesome (main, rotated, right; HDMI mirror
      # off, Super+D toggles it).
      xrandr \
        --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --rotate normal --primary \
        --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --right-of DisplayPort-0 \
        --output DisplayPort-2 --mode 1920x1080 --rate 144 --rotate normal --right-of DisplayPort-1 \
        --output HDMI-A-0 --off
      # Screens only blank while locked (lock-screen turns DPMS on).
      xset s off -dpms

      # The same user services as Awesome, quickshell (the bar) included.
      # Hyprland's variables go first, in case it ran earlier this boot.
      systemctl --user unset-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP
      systemctl --user start picom.service dunst.service clipmenu.service
      systemctl --user restart quickshell.service
      dwm-bar-state &
      polkit-agent &
      openrgb --startminimized &
    '';
  };

  home.packages = [ dwmBarState dwmViewTag dwmKeys dwmMenu ];
}
