# AMD graphics + LACT, audio, bluetooth, RGB, input and power profiles.
{ pkgs, ... }:

{
  # --- Graphics (AMD) ---
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit libs, e.g. for Steam/Wine
  };
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.amdgpu.overdrive.enable = true; # required for LACT to actually overclock on AMD
  # The Arch setup's mask: the kernel default plus the overdrive bit. NixOS's
  # own default (0xfffd7fff) also turns off GFXOFF and stutter mode, which
  # only costs idle power.
  hardware.amdgpu.overdrive.ppfeaturemask = "0xfff7ffff";

  # LACT: GPU monitoring/overclocking daemon + GUI. Runs as a root systemd
  # service (lactd) since it needs direct sysfs/DRM access; the GUI just
  # talks to it over a socket.
  services.lact.enable = true;

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

  # Middle-click emulation (simultaneous left+right = middle button) is on
  # by default and fires spuriously during fast in-game clicking -- off.
  services.libinput.mouse.middleEmulation = false;

  # Still needed even with the waybar module removed -- it's the
  # actual D-Bus service `powerprofilesctl` talks to; nothing applies the
  # profile to hardware without it running.
  services.power-profiles-daemon.enable = true;

  # power-profiles-daemon has no persistence across restarts at all --
  # confirmed via its own source (power-profiles-daemon.c: unconditionally
  # hardcodes `active_profile = PPD_PROFILE_BALANCED` at every startup) --
  # so "performance" has to be re-applied after every boot, not just set
  # once by hand.
  systemd.services.set-performance-profile = {
    description = "Force power profile to performance on boot";
    after = [ "power-profiles-daemon.service" ];
    requires = [ "power-profiles-daemon.service" ];
    # graphical.target, not multi-user: since power-profiles-daemon 0.30 its
    # unit is After=multi-user.target / WantedBy=graphical.target, so running
    # this before multi-user (what wantedBy multi-user implies) while also
    # after the daemon is an ordering cycle -- confirmed live: "Transaction
    # order is cyclic" for power-profiles-daemon.service on switch.
    wantedBy = [ "graphical.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };
}
