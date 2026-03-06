# DNS-over-TLS Module
# Provides: Encrypted DNS with DNSSEC via systemd-resolved
#
# Usage:
#   myModules.dnsOverTls = {
#     enable = true;
#     dnssec = true;                              # default: true
#     primaryDns = [ "9.9.9.9" "149.112.112.112" ];  # default: Quad9
#     fallbackDns = [ "9.9.9.9" "149.112.112.112" ]; # default: Quad9
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.dnsOverTls;
in
{
  options.myModules.dnsOverTls = {
    enable = lib.mkEnableOption "DNS-over-TLS with DNSSEC";

    dnssec = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable DNSSEC validation";
    };

    primaryDns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "9.9.9.9"
        "149.112.112.112"
      ];
      description = "Primary DNS servers (Quad9 by default)";
    };

    fallbackDns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "9.9.9.9"
        "149.112.112.112"
      ];
      description = "Fallback DNS servers (Quad9 by default)";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.nameservers = cfg.primaryDns;
    networking.networkmanager.dns = "systemd-resolved";

    services.resolved = {
      enable = true;
      dnssec = if cfg.dnssec then "true" else "false";
      domains = [ "~." ];
      fallbackDns = cfg.fallbackDns;
      dnsovertls = "true";
    };
  };
}
