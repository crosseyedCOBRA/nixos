# Btrfs snapshots + scrub, zram swap and the external drives.
{ ... }:

{
  # --- Btrfs snapshots (snapper) ---
  # Same retention as the Arch setup's /etc/snapper/configs/{root,home}:
  # hourly timeline snapshots, kept 10 hourly / 10 daily / 10 monthly /
  # 10 yearly. "/" here is the top-level subvolume, so its snapshots skip
  # the nested nix and home subvolumes -- /nix is already covered by NixOS
  # generations, and /home gets its own config. snapper won't create the
  # .snapshots subvolumes itself; the tmpfiles `v` rules below do.
  # `sudo snapper -c home list` / `undochange` to get files back.
  services.snapper.configs =
    let
      common = {
        FSTYPE = "btrfs";
        SPACE_LIMIT = "0.5";
        FREE_LIMIT = "0.2";
        NUMBER_CLEANUP = true;
        NUMBER_MIN_AGE = 3600;
        NUMBER_LIMIT = 50;
        NUMBER_LIMIT_IMPORTANT = 10;
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_MIN_AGE = 3600;
        TIMELINE_LIMIT_HOURLY = 10;
        TIMELINE_LIMIT_DAILY = 10;
        TIMELINE_LIMIT_WEEKLY = 0;
        TIMELINE_LIMIT_MONTHLY = 10;
        TIMELINE_LIMIT_QUARTERLY = 0;
        TIMELINE_LIMIT_YEARLY = 10;
        EMPTY_PRE_POST_CLEANUP = true;
        EMPTY_PRE_POST_MIN_AGE = 3600;
      };
    in
    {
      root = common // { SUBVOLUME = "/"; };
      home = common // { SUBVOLUME = "/home"; };
    };
  systemd.tmpfiles.rules = [
    "v /.snapshots 0750 root root -"
    "v /home/.snapshots 0750 root root -"
  ];
  # Monthly checksum scrub of the whole filesystem, so silent corruption
  # shows up in the journal instead of in a snapshot you try to restore.
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };

  # --- zram swap ---
  zramSwap.enable = true;

  # --- External drives ---
  # nofail so boot doesn't hang/fail if the drive is unplugged. (The WD 1 TB
  # SSD that was /mnt/wd is set aside for a Windows install, 2026-11.)
  fileSystems."/mnt/samsung" = {
    device = "/dev/disk/by-uuid/f2602e89-279c-42e7-8f9c-0b2cbeb06bcc";
    fsType = "xfs";
    options = [ "nofail" ];
  };
}
