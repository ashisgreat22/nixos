{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.myModules.secureBoot;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.myModules.secureBoot = {
    enable = mkEnableOption "Secure Boot with Lanzaboote";

    pkiBundle = mkOption {
      type = types.path;
      default = "/var/lib/sbctl";
      description = "Path to the PKI bundle directory created by sbctl";
    };
  };

  config = mkIf cfg.enable {
    # Lanzaboote replaces systemd-boot
    boot.loader.systemd-boot.enable = mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = cfg.pkiBundle;
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
