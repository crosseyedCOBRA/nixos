# Arch Linux Manual Install — UEFI / Btrfs + Snapper / Awesome + XLibre

Everything below is typed in the live ISO terminal. Boot the Arch ISO,
and you'll land at a root prompt. UEFI-only and ethernet-only (no Wi-Fi
branches) since that's this machine.


## 1. Verify Boot Mode (should say 64)

```
cat /sys/firmware/efi/fw_platform_size
```

If this file doesn't exist, you're not booted in UEFI mode — reboot and
fix that in firmware settings before continuing.


## 2. Connect to the Internet (ethernet)

```
ip a
ping -c 3 archlinux.org
```

If that doesn't work, check the cable/link light before doing anything
else — nothing past this point works without a connection.


## 3. Update System Clock

```
timedatectl set-ntp true
timedatectl status
```


## 4. Partition the Disk

Find your disk:
```
lsblk
```

Common names: `/dev/sda` (SATA), `/dev/nvme0n1` (NVMe). The examples
below use `/dev/sda`; substitute your actual device (and `p1`/`p2`
instead of `1`/`2` if it's an NVMe drive).

```
fdisk /dev/sda
```

Inside fdisk:
```
g              ← create new GPT table
n              ← new partition
  1            ← partition number
  [Enter]      ← default first sector
  +512M        ← size for EFI
t              ← change type
  1            ← EFI System

n              ← new partition
  2            ← partition number
  [Enter]      ← default first sector
  [Enter]      ← use remaining space (entire rest of disk)

w              ← write and exit
```

Result:
- `/dev/sda1` → 512M EFI
- `/dev/sda2` → rest → Linux root (Btrfs)


## 5. Format Partitions

```
mkfs.fat -F32 /dev/sda1
mkfs.btrfs -f /dev/sda2
```


## 6. Create Btrfs Subvolumes

This is the layout snapper expects and that keeps rollbacks clean:
`@` (root) and `@home` get snapshotted together with the rest of the
system, while `@var_log` and `@pkg` (pacman's package cache) are split
out so log churn and re-downloadable packages don't bloat every
snapshot. `@snapshots` holds snapper's own snapshot data.

```
mount /dev/sda2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@pkg
umount /mnt
```

Now mount everything at its real path using those subvolumes:

```
mount -o noatime,compress=zstd,subvol=@ /dev/sda2 /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,boot/efi}
mount -o noatime,compress=zstd,subvol=@home     /dev/sda2 /mnt/home
mount -o noatime,compress=zstd,subvol=@var_log  /dev/sda2 /mnt/var/log
mount -o noatime,compress=zstd,subvol=@pkg      /dev/sda2 /mnt/var/cache/pacman/pkg
mount /dev/sda1 /mnt/boot/efi
```

(`@snapshots` is deliberately not mounted yet — snapper needs to create
its own `.snapshots` subvolume from scratch after install, see step 12.
Creating it now would just get in its way.)


## 7. Install Base System

```
pacstrap -K /mnt base linux linux-firmware base-devel \
    btrfs-progs networkmanager sudo neovim git
```

`btrfs-progs` is critical — without it Btrfs won't mount on reboot.


## 8. Generate fstab

```
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

Verify it looks right — you should see four Btrfs entries (root, home,
var/log, pacman pkg cache) all pointing at the same UUID with different
`subvol=` options, plus the EFI partition.


## 9. Chroot

```
arch-chroot /mnt
```


## 10. Timezone & Locale

```
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc
```

Edit locale:
```
nvim /etc/locale.gen
```
Uncomment: `en_US.UTF-8 UTF-8`

Generate:
```
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```


## 11. Hostname

```
echo "archbox" > /etc/hostname
```

Edit `/etc/hosts`:
```
nvim /etc/hosts
```
Add:
```
127.0.0.1   localhost
::1         localhost
127.0.1.1   archbox.localdomain archbox
```


## 12. Root Password, User, and Sudo

```
passwd
useradd -m -G wheel,audio,video,input,network -s /bin/bash yourusername
passwd yourusername
EDITOR=nvim visudo
```
Uncomment: `%wheel ALL=(ALL:ALL) ALL`


## 13. Snapper Setup

Install snapper:
```
pacman -S --noconfirm snapper
```

Snapper wants to create its own `.snapshots` subvolume the first time
you configure it, so let it, then swap in the `@snapshots` subvolume
you actually want long-term:

```
umount /mnt 2>/dev/null || true
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
```

Now mount the real `@snapshots` subvolume there permanently. Find your
root partition's UUID:
```
blkid /dev/sda2
```

Add this line to `/etc/fstab` (replace `UUID-HERE` with the value from
`blkid`, matching the format of the other Btrfs lines already there):
```
UUID=UUID-HERE  /.snapshots  btrfs  rw,noatime,compress=zstd,subvol=@snapshots  0 0
```

Then:
```
mount -a
chmod 750 /.snapshots
```

Enable automatic timeline snapshots:
```
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer
```

From here on, `sudo snapper -c root create --description "before X"` is
worth running before anything risky (a big update, a driver change),
and `sudo snapper -c root list` / `snapper -c root rollback <number>`
is how you get back out of a bad state — this is the whole reason for
doing this over XFS.


## 14. Bootloader (GRUB)

```
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

GRUB auto-detects the Btrfs subvolume layout and adds the right
`rootflags=subvol=@` on its own — no manual kernel parameter needed.


## 15. Enable NetworkManager

```
systemctl enable NetworkManager
```


## 16. Exit and Reboot

```
exit
umount -R /mnt
reboot
```

Remove the USB. Boot into your new Arch system, log in as your user.


## 17. Run the Post-Install Script

Transfer `arch-post-install.sh` to the machine (and your `wallpaper.jpg`
into the same directory, if you want it auto-installed) and run:

```
chmod +x arch-post-install.sh
sudo ./arch-post-install.sh
```

Then reboot. LightDM appears, select Awesome, log in.
