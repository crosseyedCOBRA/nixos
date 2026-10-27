# Printing, virtual machines and SSH.
{ ... }:

{
  # --- Printing ---
  services.printing.enable = true;

  # --- Virtual machines ---
  # KVM via libvirt, managed from virt-manager. Needs SVM turned on in the
  # BIOS (it was off: "SVM disabled (by BIOS) in MSR_VM_CR" in dmesg);
  # without it libvirt still starts but can only run slow emulated VMs.
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # --- SSH ---
  # Agent runs for the whole login session; AddKeysToAgent means the key's
  # passphrase (if it has one) is asked for once, on first use, not on
  # every git push.
  programs.ssh.startAgent = true;
  programs.ssh.extraConfig = ''
    AddKeysToAgent yes
  '';
}
