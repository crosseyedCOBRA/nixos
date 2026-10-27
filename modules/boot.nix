# Bootloader, kernel and scheduler.
{ pkgs, ... }:

{
  # --- Bootloader ---
  # Assumes UEFI. If this machine is legacy BIOS, swap this for boot.loader.grub instead.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true; # adds a memtest86+ boot-menu entry
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
  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
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
