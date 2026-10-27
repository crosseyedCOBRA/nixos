{ config, lib, pkgs, username, inputs, ... }:

{
  # The first three each add a slice of home.packages; the combined list
  # follows this import order.
  imports = [
    ./home/awesome.nix
    ./home/streaming.nix
    ./home/hyprland.nix
    ./home/theming.nix
    ./home/shell.nix
    ./home/browsers.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  home.sessionVariables = {
    EDITOR = "vim";
  };

  # `xsession.enable` is deliberately left off (it would also generate an
  # unconditional ~/.xsession that hijacks every login-screen session choice
  # back into i3 — see the multi-session setup in modules/desktop.nix). But
  # every session's generic launch script still sources ~/.xprofile if
  # present, so recreate
  # just that one piece by hand: without it, home.sessionVariables (EDITOR,
  # QT_QPA_PLATFORMTHEME, etc.) never reach the session's actual
  # process tree, only systemd-managed services like quickshell.
  home.file.".xprofile".text = ''
    . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  programs.home-manager.enable = true;

  xdg.enable = true;
}
