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

  # sp5100_tco (AMD SP5100/SB800 chipset hardware watchdog timer) is what
  # was actually behind the "watchdog0: watchdog did not stop!" hang on
  # shutdown/reboot -- confirmed via journalctl on this exact machine
  # (a kernel message, nothing to do with Hyprland despite the similar
  # wording). The kernel can't always cleanly disable this specific
  # hardware watchdog once armed, and nothing here intentionally uses it
  # (it's meant for auto-reboot-on-hang server scenarios) -- blacklisting
  # it outright means it's never armed in the first place.
  boot.blacklistedKernelModules = [ "sp5100_tco" ];

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

  # --- RGB lighting (OpenRGB) ---
  # Runs the OpenRGB SDK server as a systemd service; also installs the
  # package, udev rules, and i2c-piix4 (AMD SMBus) for motherboard/RAM RGB.
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  # --- X11 + Awesome ---
  # Awesome is the daily-driver window manager: chosen over i3, Plasma, and
  # the XFCE/Cinnamon DEs tried for testing, for its native dwindle/master
  # layouts, real mouse-driven tiling, and per-monitor tags without needing
  # patches. Hyprland (below) is a second, genuinely-riced session, not a
  # replacement -- see ./hyprland/.
  services.xserver.enable = true;
  services.xserver.windowManager.awesome.enable = true;

  # --- Hyprland ---
  # Registers its session via services.displayManager.sessionPackages; no
  # display-manager coupling by itself, but see services.greetd below for
  # why lightdm cant be the display manager anymore now that this exists.
  # xwayland.enable defaults to true, needed for Steam/Heroic under it.
  # Config lives in ./hyprland/ (see home.nix for how its deployed).
  programs.hyprland.enable = true;

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
      in
      lib.concatStringsSep " " [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember --remember-session" # sticky across reboots/logouts
        "--xsessions ${sessions}/share/xsessions"
        "--sessions ${sessions}/share/wayland-sessions"
        # Hyprland as the initial default: --cmd sets what runs before any
        # session has ever been manually picked. --remember-session then
        # overrides this with whatever *was* picked, on every login after
        # the first manual selection (per tuigreet's own docs).
        "--cmd ${config.programs.hyprland.package}/bin/start-hyprland"
      ];
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
  # (only LightDM/GDM/SDDM read it) -- kept in sync with the --cmd default
  # above purely so this file doesnt contradict itself, plus it still
  # feeds the sessionNames assertion. The actual default comes from
  # tuigreet's --cmd/--remember-session, not this option.
  services.displayManager.defaultSession = "hyprland";

  # Middle-click emulation (simultaneous left+right = middle button) is on
  # by default and fires spuriously during fast in-game clicking -- off.
  services.libinput.mouse.middleEmulation = false;

  # Still needed even with the waybar module removed (below) -- it's the
  # actual D-Bus service `powerprofilesctl` talks to; nothing applies the
  # profile to hardware without it running.
  services.power-profiles-daemon.enable = true;

  # swayosd's own udev rule (lib/udev/rules.d/99-swayosd.rules), granting
  # its server process backlight sysfs write access -- see the swayosd
  # comment in environment.systemPackages above for the polkit half.
  services.udev.packages = [ pkgs.swayosd ];

  # power-profiles-daemon has no persistence across restarts at all --
  # confirmed via its own source (power-profiles-daemon.c: unconditionally
  # hardcodes `active_profile = PPD_PROFILE_BALANCED` at every startup) --
  # so "performance" has to be re-applied after every boot, not just set
  # once by hand.
  systemd.services.set-performance-profile = {
    description = "Force power profile to performance on boot";
    after = [ "power-profiles-daemon.service" ];
    requires = [ "power-profiles-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };

  # Required for i3lock to actually authenticate: this generates
  # /etc/pam.d/i3lock. Without it, i3lock has no PAM stack to check the
  # password against and rejects every attempt, correct or not -- the
  # i3 window manager module sets this automatically, but nothing does
  # for Awesome, so it must be requested explicitly here.
  programs.i3lock.enable = true;

  # Same PAM requirement as i3lock above, for hyprlock (Hyprland session,
  # see ./hyprland/hyprlock.conf). Deliberately not programs.hyprlock.enable:
  # that module also force-enables services.hypridle (idle-triggered
  # auto-lock/DPMS), which nothing here asked for and which conflicts with
  # this system's existing "screens never auto-blank, only the lock script
  # re-enables DPMS" design (see rc.lua/home.nix's lock-screen). Just the
  # PAM stack is needed for a manually-invoked hyprlock to authenticate.
  security.pam.services.hyprlock = { };

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

  # --- nix-ld ---
  # Patches the dynamic loader for non-Nix binaries, e.g. compiled wheels
  # (MarkupSafe, etc.) pulled in by pip inside a python venv, which
  # otherwise can't find their libs since NixOS has no /lib64/ld-linux.
  programs.nix-ld.enable = true;

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
    inter # waybar/wofi's font-family (./hyprland/waybar/style.css, ./hyprland/wofi/style.css)
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
    xinit # provides `startx`, tuigreet's default X11 session wrapper (see services.greetd above)
    curl
    git
    unzip
    p7zip
    file
    python3
    chromium
    brave
    claude-code
    vesktop
    xdg-user-dirs
    gnome-calculator
    vscodium
    inputs.zen-browser.packages.${pkgs.system}.default # beta channel

    # swayosd: volume/brightness OSD (see hyprland.lua's XF86Audio*/
    # XF86MonBrightness* binds). Installed system-wide (not just via
    # home.packages) so its polkit action file
    # (share/polkit-1/actions/org.erikreider.swayosd.policy) gets picked
    # up -- polkit aggregates actions from the system profile, not the
    # per-user home-manager one. services.udev.packages below is the
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

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
  };
  programs.gamemode = {
    enable = true;
    # Pauses the wallpaper timer (home.nix's random-wallpaper-timer) for
    # as long as any gamemoderun-wrapped game is actually running, since
    # every installed game already launches through it -- no separate
    # manual toggle to remember. gamemoded is D-Bus-activated (confirmed:
    # no persistent gamemoded.service exists to check its running user
    # against), so its execution context for these scripts isn't
    # something to assume -- --machine=<user>@ is the standard, safe way
    # to target a specific user's systemd --user session bus regardless
    # of whether the caller turns out to already be that user or a more
    # privileged one.
    # Confirmed live via journalctl --user -u gamemoded: these run through
    # /bin/sh with a minimal PATH that doesn't include systemctl at all
    # ("systemctl: command not found", script exit 127) -- same PATH-
    # resolution class of bug as greetd/the wallpaper timer's own
    # apply-colors call earlier. Full store path instead of relying on
    # PATH.
    settings.custom = {
      start = "${pkgs.systemd}/bin/systemctl --user --machine=${username}@ stop random-wallpaper-timer.timer";
      end = "${pkgs.systemd}/bin/systemctl --user --machine=${username}@ start random-wallpaper-timer.timer";
    };
  };
  # gamemode's own actual performance tweaks (CPU governor, split-lock
  # mitigation) were failing outright: `pkexec: Not authorized` for
  # cpugovctl/procsysctl (confirmed live via journalctl --user -u
  # gamemoded). Root cause: the gamemode package DOES ship its own
  # polkit rule (share/polkit-1/rules.d/gamemode.rules, granting a
  # "gamemode" group passwordless access to exactly these action IDs),
  # and it IS correctly aggregated into
  # /run/current-system/sw/share/polkit-1/rules.d/ -- but polkit's own
  # daemon never actually reads rules from that path. It only reads
  # /etc/polkit-1/rules.d/, which on NixOS is just one
  # NixOS-generated file (10-nixos.rules) with a fixed set of built-in
  # rules, not something that dynamically incorporates arbitrary
  # installed packages' own rules.d files. security.polkit.extraConfig
  # is what actually gets included in that generated file. Targets
  # "wheel" (already used for mike) instead of gamemode's own
  # "gamemode" group, to avoid also needing to create and assign a new
  # group just for this.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if ((action.id == "com.feralinteractive.GameMode.governor-helper" ||
           action.id == "com.feralinteractive.GameMode.gpu-helper" ||
           action.id == "com.feralinteractive.GameMode.cpu-helper" ||
           action.id == "com.feralinteractive.GameMode.procsys-helper") &&
          subject.isInGroup("wheel"))
      {
          return polkit.Result.YES;
      }
    });
  '';
  hardware.steam-hardware.enable = true; # controller udev rules
  # Several UE5 titles (Monster Hunter Wilds, Lords of the Fallen, The Blood
  # of Dawnwalker) crash or fail to launch under Proton with the kernel's
  # default map-count limit.
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  # --- External drives ---
  # nofail so boot doesn't hang/fail if either drive is unplugged.
  fileSystems."/mnt/wd" = {
    device = "/dev/disk/by-uuid/bfc665b1-20ba-4eca-927e-aaa2cc0656ae";
    fsType = "xfs";
    options = [ "nofail" ];
  };
  fileSystems."/mnt/samsung" = {
    device = "/dev/disk/by-uuid/f2602e89-279c-42e7-8f9c-0b2cbeb06bcc";
    fsType = "xfs";
    options = [ "nofail" ];
  };

  # --- Flatpak apps (declarative via nix-flatpak) ---
  services.flatpak.packages = [
    "org.pvermeer.WebAppHub" # web app installer
    "eu.betterbird.Betterbird" #email client
    "com.chatterino.chatterino" #chatterino
    "io.github.radiolamp.mangojuice" #mangojuice
    "com.notesnook.Notesnook" #notesnook
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data were taken. Do NOT bump this on later
  # upgrades — it should stay at whatever it was on first install.
  system.stateVersion = "26.05";
}
