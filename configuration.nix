{ config, pkgs, lib, username, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- Bootloader ---
  # Assumes UEFI. If this machine is legacy BIOS, swap this for boot.loader.grub instead.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # NixOS's default `linuxPackages` is a conservative pin, not the newest
  # available kernel — use the latest stable release instead.
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  # --- Graphics (AMD) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit libs, e.g. for Steam/Wine
  };
  services.xserver.videoDrivers = [ "amdgpu" ];

  # --- Audio (pipewire) ---
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # --- X11 + Awesome ---
  # Awesome is the sole daily-driver WM: chosen over i3, XFCE, dwm, and the
  # Wayland compositors tried earlier for its native dwindle/master layouts,
  # real mouse-driven tiling, and per-monitor tags without needing patches.
  services.xserver.enable = true;
  services.xserver.windowManager.awesome.enable = true;
  # Reverted from greetd+tuigreet back to lightdm: greetd's X11 handling
  # (sessions run through tuigreet's `startx` wrapper) turned out to be
  # broken too (sessions opened and crashed within the same second per the
  # journal), and since the Wayland WMs greetd was for are gone, there's no
  # remaining reason not to go back to the known-good lightdm setup.
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.defaultSession = "none+awesome";

  # --- Monitor layout ---
  # DisplayPort-0: primary, 165Hz. DisplayPort-1: rotated 90° right, to the
  # right of DP-0. DisplayPort-2: further right of (rotated) DP-1, 144Hz.
  # HDMI-A-0 (mirrors DisplayPort-0, native 4K) stays off by default —
  # mirroring it had a real performance cost (likely an XLibre clone-mode
  # bug) — and is toggled on/off on demand via Mod+d (the `toggle-hdmi`
  # script).
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xrandr}/bin/xrandr \
      --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --rotate normal --primary \
      --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --right-of DisplayPort-0 \
      --output DisplayPort-2 --mode 1920x1080 --rate 144 --rotate normal --right-of DisplayPort-1 \
      --output HDMI-A-0 --off
  '';

  # --- Theming ---
  # Required by home-manager's `dconf.settings` (used for GTK dark mode).
  programs.dconf.enable = true;

  # --- Flatpak + desktop portals ---
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # --- Fonts ---
  # Pulls in every packaged Nerd Font (several GB) since all of them were requested.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
  ] ++ lib.attrValues (lib.filterAttrs (_: lib.isDerivation) nerd-fonts);

  # --- Printing ---
  services.printing.enable = true;

  # --- zram swap ---
  zramSwap.enable = true;

  # --- User account ---
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    shell = pkgs.bash;
  };
  # No password is set here. After the first rebuild, log in at the TTY
  # and run `passwd` to set one (or `passwd mike` as root).

  environment.systemPackages = with pkgs; [
    vim
    fastfetch
    wget
    curl
    git
    unzip
    p7zip
    file
    chromium
    brave
    claude-code
    vesktop
    inputs.zen-browser.packages.${pkgs.system}.default # beta channel

    # --- Gaming ---
    mangohud
    lutris
    heroic
    protonup-qt
    wineWow64Packages.stable
    winetricks
  ];

  programs.firefox.enable = true;

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamemode.enable = true;
  hardware.steam-hardware.enable = true; # controller udev rules

  # --- Flatpak apps (declarative via nix-flatpak) ---
  services.flatpak.packages = [
    "org.pvermeer.WebAppHub" # web app installer
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data were taken. Do NOT bump this on later
  # upgrades — it should stay at whatever it was on first install.
  system.stateVersion = "26.05";
}
