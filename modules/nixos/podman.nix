# Podman Module
# Provides: Rootless Podman container runtime with Docker compatibility
#
# Usage:
#   myModules.podman = {
#     enable = true;
#     dockerCompat = true;     # default: true
#     enableDns = true;        # default: true
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.podman;
in
{
  options.myModules.podman = {
    enable = lib.mkEnableOption "Podman container runtime";

    dockerCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Docker CLI compatibility (docker alias)";
    };

    enableDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable DNS for container networking";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = cfg.dockerCompat;
        defaultNetwork.settings.dns_enabled = cfg.enableDns;
      };
      oci-containers.backend = "podman";
    };

    # Required for rootless podman image pulling
    environment.etc."containers/policy.json".text = lib.mkForce (
      builtins.toJSON {
        default = [ { type = "insecureAcceptAnything"; } ];
        transports = {
          docker-daemon = {
            "" = [ { type = "insecureAcceptAnything"; } ];
          };
        };
      }
    );

    environment.systemPackages = [ pkgs.podman ];

    # Ensure required kernel modules are loaded at boot for locked kernel
    boot.kernelModules = [
      "veth" # Required for netavark to create container network interfaces
      "bridge"
      "br_netfilter"
      "tap"
      "tun"
      "loop"
      "nft_ct"
      "nft_nat"
      "nft_chain_nat"
      "nft_compat"
      "nft_masq"
      "nft_reject_inet"
      "nft_reject_ipv4"
      "nft_reject_ipv6"
      "nft_fib_inet"
      # IPTables extensions commonly used by Podman/Docker
      "xt_conntrack"
      "xt_comment"
      "xt_addrtype"
      "xt_mark"
      "xt_multiport"
      "xt_nat"

      # NAT/Masquerade support
      "xt_MASQUERADE"
      "iptable_nat"
      "iptable_filter"
    ];
  };
}
