{ config, pkgs, lib, modulesPath, ... }:

{
  boot = {
    loader.external = {
      enable = true;
      installHook = pkgs.writeShellScript "install-pmon-boot-cfg" ''
        exec ${lib.getExe pkgs.pmon-boot-cfg} ${builtins.storeDir} /boot '(wd0,0)' "$@"
      '';
    };

    kernelPackages = pkgs.linuxPackages_lemote2f;
  };

  system.boot.loader.kernelFile = lib.mkForce "vmlinuz-${config.boot.kernelPackages.kernel.modDirVersion}"; 

  system.requiredKernelConfig = lib.mkForce [];

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/sakimi-boot";
    options = [ "noatime" ];
    fsType = "vfat";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/sakimi-nixos";
    options = [ "noatime" ];
    fsType = "ext4";
  };

  networking.hostName = "sakimi";

  documentation.nixos.enable = false;
  security.polkit.enable = false;
  services.udisks2.enable = false;
  systemd.shutdownRamfs.enable = false;
  services.nscd.enableNsncd = false;
  programs.less.lessopen = null;
  services.timesyncd.enable = false;
  systemd.services.audit.enable = false; # No audit on MIPS
  networking.firewall.logRefusedConnections = false;

  fonts = {
    fontconfig.enable = true;
    packages = [
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
    ];
  };

  services = {
    gpm.enable = true;
    getty.autologinUser = "dram";
    openssh = {
      enable = true;
      ports = [ 22649 ];
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };

  networking.supplicant.wlp0s14f5u4 = {
    configFile.path = "/var/wpa_supplicant.conf";
    configFile.writable = true;
    userControlled.enable = true;
  };

  security.sudo.wheelNeedsPassword = false;

  users = {
    mutableUsers = false;
    users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2X4EKIQTUUctgGnrXhHYddKzs69hXsmEK2ePBzSIwM"
    ];
    users.dram = {
      isNormalUser = true;
      extraGroups = [ "wheel" "video" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII2X4EKIQTUUctgGnrXhHYddKzs69hXsmEK2ePBzSIwM"
      ];
    };
  };

  services.journald.extraConfig = ''
    Storage=volatile
  '';

  environment.systemPackages = with pkgs; [
    fbterm
    jq
    lm_sensors
    lynx
    pciutils
    pfetch
    tmux
    usbutils
    w3m
    wpa_supplicant
    gcc
    binutils
  ];

  system.stateVersion = "21.11";
}
