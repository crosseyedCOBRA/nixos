{ config, pkgs, lib, username, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/hardware.nix
    ./modules/desktop.nix
    ./modules/awesome.nix
    ./modules/hyprland.nix
    ./modules/services.nix
    ./modules/storage.nix
    ./modules/packages.nix
    ./modules/gaming.nix
  ];

  # --- Networking ---
  networking.hostName = "nixos"; # keep in sync with flake.nix's `hostname` let-binding
  networking.networkmanager.enable = true;

  # --- Locale / time ---
  time.timeZone = "America/New_York"; # change to your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";

  # --- Nix / nixpkgs ---
  nixpkgs.config.allowUnfree = true; # non-free software allowed
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # --- User account ---
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "libvirtd" ];
    # fish, same as the Arch setup -- its config and the starship prompt are
    # in home/shell.nix (programs.fish / programs.starship).
    shell = pkgs.fish;
  };
  # Needed alongside users.users.*.shell: adds fish to /etc/shells and sets
  # up NixOS's environment and vendor completions for it.
  programs.fish.enable = true;
  # No password is set here. After the first rebuild, log in at the TTY
  # and run `passwd` to set one (or `passwd mike` as root).

  # This value determines the NixOS release from which the default
  # settings for stateful data were taken. Do NOT bump this on later
  # upgrades — it should stay at whatever it was on first install.
  system.stateVersion = "26.05";
}
