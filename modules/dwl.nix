# My dwl (Wayland): built from the `dwl` flake input (~/src/dwl) with
# nixpkgs' dwl recipe, and a "dwl" session in the login screen's F3 menu.
# nixpkgs' programs.dwl starts dwl with a command that hands WAYLAND_DISPLAY
# to systemd user services and starts dwl-session.target (which pulls in
# graphical-session.target). config.h in the repo is the config.
{ inputs, pkgs, username, ... }:

{
  programs.dwl = {
    enable = true;
    package = pkgs.dwl.overrideAttrs (old: {
      src = inputs.dwl;
      version = "0.9-mine";
    });
    # Name the desktop, so xdg-desktop-portal picks dwl's portals
    # (dwl-portals.conf, ./desktop.nix): the wlroots one for screen sharing.
    # The portals run as systemd user services, so they get it too.
    # home-manager's session variables (EDITOR, the Qt theme, the cursor,
    # ...) too: a Wayland session doesn't read ~/.xprofile, which was how
    # they reached the X sessions. The systemd services (the bar, portals)
    # get them as well.
    extraSessionCommands = ''
      . /etc/profiles/per-user/${username}/etc/profile.d/hm-session-vars.sh
      export XDG_CURRENT_DESKTOP=dwl
      vars="XDG_CURRENT_DESKTOP EDITOR QT_QPA_PLATFORMTHEME QT_PLUGIN_PATH QML2_IMPORT_PATH XCURSOR_THEME XCURSOR_SIZE XCURSOR_PATH GTK2_RC_FILES"
      systemctl --user import-environment $vars
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd $vars
    '';
  };

  # Screen sharing and screenshots for apps (OBS, Discord, browsers) through
  # the desktop portal, on wlroots compositors. It asks which monitor to
  # share with slurp: click one.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
}
