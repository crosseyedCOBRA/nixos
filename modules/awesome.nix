# X11 + Awesome session (system side), including the xrandr monitor layout.
# Hyprland's monitors are in ../hyprland/hyprland.lua.
{ pkgs, ... }:

{
  # --- X11 + Awesome ---
  # Awesome is the daily-driver window manager: chosen over i3, Plasma, and
  # the XFCE/Cinnamon DEs tried for testing, for its native dwindle/master
  # layouts, real mouse-driven tiling, and per-monitor tags without needing
  # patches. Hyprland (./hyprland.nix) is a second, genuinely-riced session, not a
  # replacement -- see ../hyprland/.
  services.xserver.enable = true;
  services.xserver.windowManager.awesome.enable = true;

  # Required for i3lock to actually authenticate: this generates
  # /etc/pam.d/i3lock. Without it, i3lock has no PAM stack to check the
  # password against and rejects every attempt, correct or not -- the
  # i3 window manager module sets this automatically, but nothing does
  # for Awesome, so it must be requested explicitly here.
  programs.i3lock.enable = true;

  # --- Monitor layout ---
  # DisplayPort-0: primary, 165Hz. DisplayPort-1: rotated 90° right, to the
  # right of DP-0. DisplayPort-2: further right of (rotated) DP-1, 144Hz.
  # HDMI-A-0 (mirrors DisplayPort-0, native 4K) stays off by default —
  # mirroring it had a real performance cost (likely an XLibre clone-mode
  # bug) — and is toggled on/off on demand via Mod+d (the `toggle-hdmi`
  # script).
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xrandr}/bin/xrandr \
      --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --rotate normal --primary \
      --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --right-of DisplayPort-0 \
      --output DisplayPort-2 --mode 1920x1080 --rate 144 --rotate normal --right-of DisplayPort-1 \
      --output HDMI-A-0 --off
  '';
}
