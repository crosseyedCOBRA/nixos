# Bootloader, kernel and scheduler.
{ lib, pkgs, ... }:

{
  # --- Bootloader ---
  # systemd-boot, installed and signed by lanzaboote for Secure Boot (which
  # Vanguard needs on the Windows side). Keys come from `sudo sbctl
  # create-keys` (in /var/lib/sbctl) and are enrolled in the firmware with
  # `sudo sbctl enroll-keys --microsoft` -- Microsoft's keys too, so Windows
  # and the GPU's option ROM still boot. lanzaboote replaces the systemd-boot
  # module, hence the mkForce; that also drops its memtest86+ menu entry,
  # which couldn't boot unsigned under Secure Boot anyway.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # NixOS's default `linuxPackages` is a conservative pin, not the newest
  # available kernel — use the latest stable release instead.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Here rather than in hardware-configuration.nix: nixos-generate-config
  # leaves kvm-amd out whenever SVM is off in the BIOS, and regenerating
  # that file after a reinstall shouldn't quietly drop VM support.
  # ntsync: kernel-side NT sync primitives that Proton 11 / Wine use instead
  # of esync/fsync when /dev/ntsync exists. Not autoloaded on demand, so it
  # has to be loaded at boot -- same as the Arch setup's modules-load.d.
  boot.kernelModules = [ "kvm-amd" "ntsync" ];

  # sched-ext: swap the kernel's default CFS/EEVDF scheduler for a
  # BPF-loaded one. scx_bpfland prioritizes low latency for
  # interactive/foreground tasks (games, audio) over raw throughput.
  # scx_loader starts it at boot (services.scx was replaced by this); the
  # running scheduler can also be switched live with `scxctl`.
  services.scx-loader = {
    enable = true;
    config.default_sched = "scx_bpfland";
  };

  # sp5100_tco (AMD SP5100/SB800 chipset hardware watchdog timer) is what
  # was actually behind the "watchdog0: watchdog did not stop!" hang on
  # shutdown/reboot -- confirmed via journalctl on this exact machine
  # (a kernel message, nothing to do with Hyprland despite the similar
  # wording). The kernel can't always cleanly disable this specific
  # hardware watchdog once armed, and nothing here intentionally uses it
  # (it's meant for auto-reboot-on-hang server scenarios) -- blacklisting
  # it outright means it's never armed in the first place.
  boot.blacklistedKernelModules = [ "sp5100_tco" ];
}
