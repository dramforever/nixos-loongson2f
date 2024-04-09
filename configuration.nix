{ config, pkgs, lib, modulesPath, ... }:

{
  programs.ssh.package = pkgs.dropbear;

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    kernelPackages = pkgs.linuxPackages_lemote2f;
  };

  system.boot.loader.kernelFile = "vmlinuz-${config.boot.kernelPackages.kernel.modDirVersion}"; 

  system.requiredKernelConfig = lib.mkForce [];

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/sakimi-boot";
    fsType = "ext2";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/sakimi-nixos";
    fsType = "ext4";
  };

  networking.hostName = "sakimi";

  documentation.nixos.enable = false;
  security.polkit.enable = false;
  services.udisks2.enable = false;
  systemd.shutdownRamfs.enable = false;
  services.nscd.enableNsncd = false;
  fonts.fontconfig.enable = false;

  services = {
    getty.autologinUser = "root";
  };

  security.sudo.wheelNeedsPassword = false;

  users = {
    mutableUsers = false;
    users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2X4EKIQTUUctgGnrXhHYddKzs69hXsmEK2ePBzSIwM"
    ];
    users.dram = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2X4EKIQTUUctgGnrXhHYddKzs69hXsmEK2ePBzSIwM"
      ];
    };
  };

  services.journald.extraConfig = ''
    Storage=volatile
  '';

  # environment.systemPackages = with pkgs; [
  #   neofetch
  # ];

  system.stateVersion = "21.11";
}
