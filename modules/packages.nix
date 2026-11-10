# System packages and Flatpak apps. Kept as one list each (not split per
# topic) so their order -- and with it the system's build hash -- doesn't
# depend on how the other modules are arranged.
{ pkgs, ... }:

let
  # protonhax isn't in nixpkgs (open request: NixOS/nixpkgs#368812) -- it's
  # a single upstream bash script (jcnils/protonhax) that lets a separate
  # program run inside an already-running Steam game's Proton/Wine
  # environment. AlecaFrame's own Linux install docs require it: Warframe's
  # launch options call `protonhax init %command%`, and AlecaFrame/Overwolf
  # then get launched into that same prefix via `protonhax exec`.
  protonhax = pkgs.stdenvNoCC.mkDerivation {
    pname = "protonhax";
    version = "unstable-2024";
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/jcnils/protonhax/main/protonhax";
      sha256 = "sha256-QSe/mW8GjH6CX1TnO/RiHJIffrv6uZZmD8+IN2Z5In8=";
    };
    dontUnpack = true;
    installPhase = ''
      install -Dm755 $src $out/bin/protonhax
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    vim
    fastfetch
    wget
    xinit # provides `startx`, tuigreet's default X11 session wrapper (see services.greetd in ./desktop.nix)
    curl
    git
    gh
    unzip
    p7zip
    file
    python3
    dmidecode # RAM/BIOS hardware info -- needs root, hence a system package
    sbctl # Secure Boot keys and status (lanzaboote, see ./boot.nix)
    chromium
    vivaldi
    firefox
    protonhax
    protontricks
    # Path of Building / PoB2 -- native Linux runtime, no Wine needed. zstd and
    # aws-lc: nixpkgs' Rust builds now link these crates' system libraries
    # instead of bundled copies, and the nixpkgs package doesn't provide them
    # yet (build fails asking for libzstd, then AWS-LC; 2026-11).
    (rusty-path-of-building.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ zstd aws-lc ];
    }))
    claude-code
    vesktop
    xdg-user-dirs
    gnome-calculator
    loupe # image viewer, default for image/* via ~/.config/mimeapps.list
    vscodium

    # swayosd: volume/brightness OSD (see hyprland.lua's XF86Audio*/
    # XF86MonBrightness* binds). Installed system-wide (not just via
    # home.packages) so its polkit action file
    # (share/polkit-1/actions/org.erikreider.swayosd.policy) gets picked
    # up -- polkit aggregates actions from the system profile, not the
    # per-user home-manager one. services.udev.packages (./desktop.nix) is the
    # other half: the udev rule granting the swayosd-server process
    # write access to backlight sysfs without running as root.
    swayosd

    # --- Gaming ---
    mangohud
    lutris
    heroic
    protonup-qt
    wineWow64Packages.stable
    winetricks
    protonplus
    papirus-icon-theme
    orchis-theme
  ];

  programs.firefox.enable = true;

  # --- nix-ld ---
  # Patches the dynamic loader for non-Nix binaries, e.g. compiled wheels
  # (MarkupSafe, etc.) pulled in by pip inside a python venv, which
  # otherwise can't find their libs since NixOS has no /lib64/ld-linux.
  programs.nix-ld.enable = true;

  # --- Flatpak apps (declarative via nix-flatpak) ---
  services.flatpak.packages = [
    "app.zen_browser.zen" # Zen browser (Flatpak since 2026-10; was the zen-browser flake)
    "com.brave.Browser" # Brave (Flatpak since 2026-11: removed from nixpkgs)
    "org.pvermeer.WebAppHub" # web app installer
    "eu.betterbird.Betterbird" #email client
    "com.chatterino.chatterino" #chatterino
    "io.github.radiolamp.mangojuice" #mangojuice
    "com.notesnook.Notesnook" #notesnook
  ];
}
