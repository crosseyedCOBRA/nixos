# Browser profile tweaks.
{ lib, pkgs, ... }:

{
  # Firefox/Zen sandbox its cubeb audio backend into the RDD process by
  # default, which is a well-documented source of intermittent audio
  # popping/crackling when the underlying backend is PipeWire (as here --
  # confirmed via `wpctl status`: Zen connects through pipewire-pulse).
  # user.js (unlike prefs.js) is read fresh on every startup and never
  # gets overwritten by the browser itself, so it's the right place for a
  # durable override outside of about:config. Path is the Flatpak Zen's
  # profile: its manifest persists ~/.zen, i.e. ~/.var/app/<id>/.zen, not
  # the XDG config dir. wyit7u4a is the profile profiles.ini marks Default
  # -- this used to target az49i3nb, a profile Zen never used, so the fix
  # never actually applied. Copied rather than linked (home.file): the
  # Flatpak sandbox has its own /nix/store without home-manager's files, so
  # a store symlink is dangling from inside Zen (confirmed: "No such file").
  home.activation.zenUserJs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -Dm644 ${pkgs.writeText "zen-user.js" ''
      user_pref("media.cubeb.sandbox", false);
    ''} "$HOME/.var/app/app.zen_browser.zen/.zen/wyit7u4a.Default Profile/user.js"
  '';
}
