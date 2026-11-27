# Shared by both sessions: the greetd/tuigreet login screen, portals,
# fonts and theming plumbing.
{ config, lib, pkgs, username, ... }:

{
  # lightdm cannot launch Hyprland (or any Wayland session) at all -- it
  # has no mechanism to start a Wayland compositor, only X. greetd+tuigreet
  # is the fix: tuigreet has *separate* `-x/--xsessions` (auto-wrapped with
  # `startx`, which itself starts the X server and sets up Xauthority) and
  # `-s/--sessions` (Wayland, run directly) flags, and routing each
  # session through the flag matching its actual type is what makes both
  # Awesome and Hyprland work from the same greeter. Verified via
  # journalctl: real successful logins across multiple boots, not just a
  # config that looks right on paper.
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command =
      let
        sessions = config.services.displayManager.sessionData.desktops;
        # dwl is the default every time the login screen comes up.
        # tuigreet has no "default session" option, only --remember-session
        # (the last pick, kept in this file), so the greeter resets that file
        # to dwl before it starts. F3 still picks Hyprland for one login.
        greeter = pkgs.writeShellScript "tuigreet-dwl-default" ''
          printf '%s\n' ${sessions}/share/wayland-sessions/dwl.desktop > /var/cache/tuigreet/lastsession-path
          exec ${tuigreet} "$@"
        '';
        tuigreet = lib.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--remember --remember-session" # username sticky; session reset to dwl above
          "--xsessions ${sessions}/share/xsessions"
          # startx alone runs the session's bare script, skipping NixOS's X
          # session setup: no DISPLAY for systemd user services (quickshell,
          # picom, dunst), no ~/.xprofile (home-manager's session variables),
          # no nixos-fake-graphical-session.target. The wrapper does all of
          # that and then execs the session.
          "--xsession-wrapper 'startx ${config.services.displayManager.sessionData.wrapper}'"
          "--sessions ${sessions}/share/wayland-sessions"
          # No --cmd: tuigreet shows a raw --cmd as its full /nix/store path
          # instead of a session name. Sessions are picked by name from the
          # F3 menu (dwl, Hyprland).
        ];
      in
      "${greeter}";
  };
  # greetd.service's own systemd PATH is a minimal curated list (coreutils/
  # findutils/grep/sed/systemd only, no /run/current-system/sw/bin).
  # `startx`'s own script shells out to more tools by bare name: `xinit`
  # (does the real work, ships alongside startx), `xauth` (sets up the X
  # cookie), and `hexdump` (generates it -- a *hard* `exit 1` if missing).
  # Hyprland's own `start-hyprland` launcher execs the real `Hyprland`
  # compositor binary by bare name too, and once running, hyprland.lua's
  # autostart (waybar/hyprpaper/wofi-power/hyprlock) execs *those* by bare
  # name as children of that same process tree -- they're home-manager
  # packages, not environment.systemPackages, so config.system.path alone
  # doesnt cover them; the per-user home-manager profile does.
  systemd.services.greetd.path = [
    config.system.path
    config.home-manager.users.${username}.home.profileDirectory
    pkgs.xauth
    pkgs.util-linux # hexdump
    pkgs.kbd # deallocvt, startx's cleanup step -- degrades gracefully if missing, included anyway
  ];
  # services.displayManager.defaultSession isnt consulted by greetd/tuigreet
  # (only LightDM/GDM/SDDM read it) -- kept for the sessionNames
  # assertion. What tuigreet starts is the session last picked in its F3
  # menu (--remember-session), not this option.
  services.displayManager.defaultSession = "dwl";

  # --- Theming ---
  # Required by home-manager's `dconf.settings` (used for GTK dark mode).
  programs.dconf.enable = true;

  # --- Flatpak + desktop portals ---
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    # Each desktop gets its own portals. "*" (any installed portal) once let
    # another desktop's portal (COSMIC's) start in Hyprland too: it held up
    # every login by about 6 seconds and could take over screen sharing.
    config = {
      common.default = [ "gtk" ]; # dwl (and anything without its own)
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };

  # --- Fonts ---
  # Pulls in every packaged Nerd Font (several GB) since all of them were requested.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
    adwaita-fonts # GTK/Qt UI font (gtk.font in ../home/theming.nix, ../hyprland/qt6ct/)
  ] ++ lib.attrValues (lib.filterAttrs (_: lib.isDerivation) nerd-fonts);

  # gdk-pixbuf ships no WebP decoder, so the two .webp wallpapers came up
  # blank in wallpaper-picker (wofi thumbnails go through gdk-pixbuf). This
  # builds a loaders.cache with the WebP loader added and points every
  # GTK app at it via GDK_PIXBUF_MODULE_FILE -- needs a re-login to apply.
  programs.gdk-pixbuf.modulePackages = [ pkgs.webp-pixbuf-loader ];
}
