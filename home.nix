{ config, lib, pkgs, username, inputs, ... }:

{
  # Several of these add a slice of home.packages; the combined list follows
  # this import order.
  imports = [
    ./home/awesome.nix
    ./home/dwl.nix
    ./home/hyprland.nix
    ./home/streaming.nix
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

  programs.home-manager.enable = true;

  xdg.enable = true;
}
