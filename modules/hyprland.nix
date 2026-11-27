# Hyprland session (system side). Its config lives in ../hyprland/ and is
# deployed by ../home/hyprland.nix.
{ pkgs, ... }:

{
  # --- Hyprland ---
  # Registers its session via services.displayManager.sessionPackages; no
  # display-manager coupling by itself, but see services.greetd (./desktop.nix) for
  # why lightdm cant be the display manager anymore now that this exists.
  # xwayland.enable defaults to true, needed for Steam/Heroic under it.
  # Config lives in ../hyprland/ (see ../home/hyprland.nix for how its deployed).
  programs.hyprland.enable = true;

  # hyprlock (the lock screen in Hyprland and dwl, see ../hyprland/hyprlock.conf)
  # needs a PAM stack to check passwords. Deliberately not programs.hyprlock.enable:
  # that module also force-enables services.hypridle (idle-triggered
  # auto-lock/DPMS), which nothing here asked for and which conflicts with
  # this system's existing "screens never auto-blank, only the lock script
  # turns them off" design (hyprlock-timeout, dwl-lock). Just the
  # PAM stack is needed for a manually-invoked hyprlock to authenticate.
  security.pam.services.hyprlock = { };

  # swayosd: volume/brightness OSD (see hyprland.lua's XF86Audio*/
  # XF86MonBrightness* binds). Installed system-wide (not just via
  # home.packages) so its polkit action file
  # (share/polkit-1/actions/org.erikreider.swayosd.policy) gets picked up --
  # polkit aggregates actions from the system profile, not the per-user
  # home-manager one. Its udev rule (lib/udev/rules.d/99-swayosd.rules) is
  # the other half: it grants swayosd-server write access to backlight sysfs
  # without running as root.
  environment.systemPackages = [ pkgs.swayosd ];
  services.udev.packages = [ pkgs.swayosd ];

  # waybar/wofi's font-family (../hyprland/waybar/style.css,
  # ../hyprland/matugen/templates/wofi-style.css).
  fonts.packages = [ pkgs.inter ];
}
