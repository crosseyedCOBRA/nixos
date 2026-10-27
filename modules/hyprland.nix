# Hyprland session (system side). Its config lives in ../hyprland/ and is
# deployed by ../home/hyprland.nix.
{ ... }:

{
  # --- Hyprland ---
  # Registers its session via services.displayManager.sessionPackages; no
  # display-manager coupling by itself, but see services.greetd (./desktop.nix) for
  # why lightdm cant be the display manager anymore now that this exists.
  # xwayland.enable defaults to true, needed for Steam/Heroic under it.
  # Config lives in ../hyprland/ (see ../home/hyprland.nix for how its deployed).
  programs.hyprland.enable = true;

  # Same PAM requirement as i3lock (./awesome.nix), for hyprlock (Hyprland session,
  # see ../hyprland/hyprlock.conf). Deliberately not programs.hyprlock.enable:
  # that module also force-enables services.hypridle (idle-triggered
  # auto-lock/DPMS), which nothing here asked for and which conflicts with
  # this system's existing "screens never auto-blank, only the lock script
  # re-enables DPMS" design (see rc.lua/../home/awesome.nix's lock-screen). Just the
  # PAM stack is needed for a manually-invoked hyprlock to authenticate.
  security.pam.services.hyprlock = { };
}
