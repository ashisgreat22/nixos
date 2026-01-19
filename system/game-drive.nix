{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Unlock secondary drive in Stage 2 (after /persist is mounted)
  environment.etc."crypttab".text = ''
    cryptdata /dev/disk/by-id/nvme-KINGSTON_SNVS1000G_50026B7784BF8876 /persist/etc/cryptdata.key header=/persist/etc/cryptdata.header
  '';

  # Ensure the mount point exists on the tmpfs root
  systemd.tmpfiles.rules = [
    "d /home/ashie/Games 0755 ashie users -"
    "L+ /home/ashie/.local/share/Steam - - - - /home/ashie/Games/Steam"
  ];

  fileSystems."/home/ashie/Games" = {
    device = "/games";
    fsType = "none";
    options = [
      "bind"
      "x-systemd.after=games.mount"
    ];
  };
}
