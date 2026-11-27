# My dwl (Wayland): built from the `dwl` flake input (~/src/dwl) with
# nixpkgs' dwl recipe, and a "dwl" session in the login screen's F3 menu.
# nixpkgs' programs.dwl starts dwl with a command that hands WAYLAND_DISPLAY
# to systemd user services and starts dwl-session.target (which pulls in
# graphical-session.target). config.h in the repo is the config.
{ inputs, pkgs, ... }:

{
  programs.dwl = {
    enable = true;
    package = pkgs.dwl.overrideAttrs (old: {
      src = inputs.dwl;
      version = "0.9-mine";
    });
  };
}
