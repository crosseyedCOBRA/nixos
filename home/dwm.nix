# dwm's startup script (the autostart patch runs it) and its status text.
# Keybindings, rules and patches are in the dwm repo itself (config.h).
{ pkgs, ... }:

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

      systemctl --user unset-environment WAYLAND_DISPLAY
      systemctl --user start picom.service dunst.service clipmenu.service
      polkit-agent &
      openrgb --startminimized &
      dwm-status &
    '';
  };

  # Status text for dwm's bar, like the Awesome bar's readouts: CPU,
  # memory, CPU temperature, network, volume, clock. Every 2s.
  home.packages = [
    (pkgs.writeShellScriptBin "dwm-status" ''
      read -r _ u n s idle iow rest < /proc/stat
      prev_total=$((u + n + s + idle + iow)); prev_idle=$((idle + iow))
      while :; do
        sleep 2
        read -r _ u n s idle iow rest < /proc/stat
        total=$((u + n + s + idle + iow)); idl=$((idle + iow))
        dt=$((total - prev_total)); di=$((idl - prev_idle))
        cpu=$(( dt > 0 ? 100 * (dt - di) / dt : 0 ))
        prev_total=$total; prev_idle=$idl

        mem=$(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{printf "%d", 100*(t-a)/t}' /proc/meminfo)
        temp=""
        for h in /sys/class/hwmon/*; do
          [ "$(cat "$h/name" 2>/dev/null)" = k10temp ] && temp=$(( $(cat "$h/temp1_input") / 1000 ))
        done
        dev=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}')
        net=$([ -n "$dev" ] && echo "$(printf '\U000f0201') $dev" || echo "$(printf '\U000f0202') offline")
        if pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q yes; then
          vol="$(printf '\uf6a9') muted"
        else
          vol="$(printf '\uf028') $(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -1)"
        fi

        xsetroot -name " $(printf '\uf4bc') $cpu% | $(printf '\uefc5') $mem% | $(printf '\uf2c7') ''${temp}°C | $net | $vol | $(date '+%a %b %d  %H:%M') "
      done
    '')
  ];
}
