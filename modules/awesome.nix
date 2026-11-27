# The X11 server for the X sessions (dwm, Zaris; XLibre, see flake.nix).
# Awesome itself is gone (2026-11-27); its helper scripts in ../awesome/bin/
# (colors, lock screen, OSD, wallpaper picker) and ../home/awesome.nix's
# bar, picom, rofi and dunst setup are what dwm uses.
{ lib, pkgs, ... }:

{
  # --- X11 ---
  services.xserver.enable = true;
  # The login screen starts X with startx (see ./desktop.nix), and startx
  # doesn't pass X the config NixOS generates -- without it X finds neither
  # the amdgpu driver (falling back to modesetting, which names the outputs
  # DP-1.. instead of the DisplayPort-0.. the xrandr layouts use) nor libinput, so the
  # keyboard and mouse never work. This writes that config to
  # /etc/X11/xorg.conf, where X looks by default.
  services.xserver.displayManager.startx.enable = true;

  # nixpkgs' X.Org server reverts an upstream damage-tracking change that
  # broke AMD drivers (xorg/xserver#1930). XLibre never took that change, so
  # the revert doesn't apply to its source and fails the build of the XLibre
  # server the xlibre-overlay swaps in (flake.nix). This drops just that
  # patch, after the xlibre overlays (mkAfter). Their X drivers are built
  # against a private copy of the server this can't reach, so the ones this
  # system loads (services.xserver.modules) are rebuilt against the fixed one.
  nixpkgs.overlays = lib.mkAfter [
    (final: prev: {
      xorg-server = prev.xorg-server.overrideAttrs (old: {
        patches = builtins.filter
          (p: (p.name or "") != "revert-damage-unlink-abi-break.patch")
          (old.patches or [ ]);
      });
    }
    // lib.genAttrs [ "xf86-video-amdgpu" "xf86-input-libinput" "xf86-input-evdev" ]
      (name: prev.${name}.override { inherit (final) xorg-server; }))
  ];

  # Required for i3lock to actually authenticate: this generates
  # /etc/pam.d/i3lock. Without it, i3lock has no PAM stack to check the
  # password against and rejects every attempt, correct or not -- the
  # i3 window manager module sets this automatically, but nothing does
  # for dwm or Zaris, so it must be requested explicitly here.
  programs.i3lock.enable = true;
  # i3lock-color: the blurred-wallpaper background, clock and themed ring
  # in ../awesome/bin/lock-screen, and media keys while locked.
  programs.i3lock.package = pkgs.i3lock-color;
}
