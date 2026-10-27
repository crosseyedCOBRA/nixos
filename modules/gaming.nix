# Steam, gamemode and game-specific tweaks. Gaming packages themselves
# (Lutris, Heroic, protonhax, ...) are in ./packages.nix.
{ pkgs, ... }:

{
  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    # Every game's launch options (../steam/launch-options.json) start with
    # `gamemoderun mangohud %command%`; this makes sure mangohud is there
    # inside Steam's FHS environment too, not just on the host PATH.
    extraPackages = [ pkgs.mangohud ];
  };
  programs.gamemode = {
    enable = true;
    # Confirmed live: "Failed to call Inhibit on org.freedesktop.
    # ScreenSaver: No route to host" -- nothing in this Hyprland session
    # implements that D-Bus interface, so this always failed outright.
    # Not something worth providing just to satisfy it, either: screens
    # here already never auto-blank unless locked (hyprlock-timeout,
    # ../hyprland/hyprland.lua), so there's nothing for it to meaningfully
    # need to inhibit in the first place.
    settings.general.inhibit_screensaver = 0;
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
}
