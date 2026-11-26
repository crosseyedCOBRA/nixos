# COSMIC (System76's Wayland desktop) as a session to try out: a full
# desktop with optional auto-tiling and its own screen-share portal, which
# works where XLibre's screen sharing doesn't. Picked from the login
# screen's F3 menu like the others; Awesome stays the default.
{ lib, ... }:

{
  services.desktopManager.cosmic.enable = true;

  # The COSMIC module also turns on system-wide extras that would reach
  # every session, Awesome included. These stay off so trying COSMIC
  # changes nothing outside it:
  # - GNOME's keyring and SSH agent: the SSH agent clashes with
  #   programs.ssh.startAgent (./services.nix), and with the keyring on,
  #   browsers would start keeping passwords in it.
  services.gnome.gnome-keyring.enable = false;
  services.gnome.gcr-ssh-agent.enable = false;
  # - A system-wide Qt theme (qt5ct): Qt apps use qt6ct, set per user in
  #   ../home/theming.nix.
  qt.enable = lib.mkForce false;
  # - System76's CPU scheduler tweaks, the Orca screen reader, Avahi
  #   (network service discovery) and GeoClue (location).
  services.system76-scheduler.enable = false;
  services.orca.enable = false;
  services.avahi.enable = false;
  services.geoclue2.enable = false;
}
