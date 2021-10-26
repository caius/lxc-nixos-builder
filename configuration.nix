{ config, lib, pkgs, modulesPath, ... }:

let
  sshKey =
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCoihjFZOiiqQMzBZ7KQ6DSePM7YdtKwq8u6ZmZNR126I95TQ15B5cUedEcIWBEVbuGIQxkRH3yKicTjr8n9lW2qxGXvSDD2xIxBFRyeluVUtiYQTpCHFUeDMyrRr9jPSBXCghkgGOw6cEX59ia06PP1UV80V4oVINDHYlc4gJZyJwQ1LXfPvXaYUBLbWfm0f2cLOaUb+NqK8b175BHsLP+plUKBAZtAMJRtd4ydCnxYTDQOD9PExOL2bOpTShyy3QjhSGfIDKXxQGKr66efhrdQwli7KEPq2QsFeerRhtMScI9RHlwBdZpxHB5GtmkNaqhlCMJ8JRgxpN6YEejcsMqkdJ0sVGnVJhYlI2McbsOMwh5F5vCBz7YGS8vEtdCKRr7c2QRtRBkQk14klKD5vldGjjujOJjRZ+fjcT/dAop8XLeV7vmmkvnTMg1L3GIlYrDpKUa2HS5hSVH6cDuO1PU9EiNvQZAY4HY1hW8c9VQ007FogsHA7bnZkVtrAfyHLc= 2021-07-11-network";
in
{
  imports =
    [
#      "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
      "${modulesPath}/installer/cd-dvd/channel.nix"
    ];

    boot.isContainer = true;
    environment.variables.NIX_REMOTE = lib.mkForce "";
    systemd.services."console-getty".enable = false;
    systemd.services."getty@"       .enable = false;

    system.build.installBootLoader = pkgs.writeScript "installBootLoader.sh" ''
      #!${pkgs.bash}/bin/bash
      export TOPLEVEL="$1"
      echo "=== installBootLoader TOPLEVEL=$TOPLEVEL"
      ${pkgs.coreutils}/bin/mkdir -p /sbin
      ${pkgs.coreutils}/bin/rm -rf /sbin/init || true     # there could be symlink to "/lib/systemd/systemd"
      ${pkgs.coreutils}/bin/cat > /sbin/init <<EOF
      #!${pkgs.bash}/bin/bash
      # lustrate old OS here (otherwise ruins of /etc would prevent NixOS to boot properly)
      if [ -e "/etc/debian_version" -o -e "/etc/redhat-release" -o -e "/etc/arch-release" -o -e "/etc/gentoo-release" ]; then
        ${pkgs.coreutils}/bin/rm -rf /bin            || true
        ${pkgs.coreutils}/bin/rm -rf /etc            || true
        ${pkgs.coreutils}/bin/rm -rf /lib            || true
        ${pkgs.coreutils}/bin/rm -rf /lib64          || true
        ${pkgs.coreutils}/bin/rm -rf /snap           || true
        ${pkgs.coreutils}/bin/rm -rf /usr            || true
        ${pkgs.coreutils}/bin/rm -rf /var            || true
      fi
      exec $TOPLEVEL/init
      EOF
      ${pkgs.coreutils}/bin/chmod 0755 /sbin/init
      # LXC: two replaces (in LXC container /dev/net/tun is pre-available, "dev-net-tun.device" always fails)
      substituteInPlace nixos/modules/tasks/network-interfaces-scripted.nix \
        --replace '[ "dev-net-tun.device" ' \
                  'optionals (!config.boot.isContainer) [ "dev-net-tun.device" ] ++ [ '
      # LXC: fix "Failed to mount Kernel Configuration File System." on "nixos-rebuild switch"
      substituteInPlace nixos/modules/system/boot/systemd.nix \
        --replace '"sys-kernel-config.mount"'         '] ++ (optional (!config.boot.isContainer) "sys-kernel-config.mount"      ) ++ [' \
        --replace '"systemd-journald-audit.socket"'   '] ++ (optional (!config.boot.isContainer) "systemd-journald-audit.socket") ++ ['
    '';
    
    fileSystems."/" = 
      { device = "/var/lib/lxd/disks/default.img";
        fsType = "btrfs";
      };

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };

    environment.systemPackages = [ pkgs.tmux ];

    # Allow SSH based login
    services.openssh = {
      enable = true;
      ports = [22];
    };

    networking = {
      # On my system eth0 is the interface used by the LXD container. YMMV.
      interfaces.eth0.useDHCP = true;
    };

    users.extraUsers.app = {
      isNormalUser = true;
      uid = 1000;
      shell = pkgs.bash;
      openssh.authorizedKeys.keys = [
        sshKey
      ];
    };

    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    system.stateVersion = "21.10"; # Did you read the comment?

    # copy the configuration.nix into /run/current-system/configuration.nix
    system.copySystemConfiguration = true;
}
