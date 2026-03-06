# Cloudflare Firewall Module
# Provides: nftables rules restricting web ports (80/443) to Cloudflare IPs only
#
# Usage:
#   myModules.cloudflareFirewall = {
#     enable = true;
#     restrictedPorts = [ 80 443 ];  # default
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.cloudflareFirewall;
  portsStr = lib.concatStringsSep ", " (map toString cfg.restrictedPorts);
in
{
  options.myModules.cloudflareFirewall = {
    enable = lib.mkEnableOption "Cloudflare-only firewall rules";

    restrictedPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        80
        443
      ];
      description = "Ports to restrict to Cloudflare IPs only";
    };

    publicPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Ports to open to the public (any IP)";
    };

    allowLocalTraffic = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow traffic from private networks (RFC1918)";
    };

    enablePodmanWorkaround = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add nftables workaround for Podman networking";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.enable = lib.mkForce false;

    # Ensure nf_conntrack is loaded for ct state rules
    boot.kernelModules = [ "nf_conntrack" ];

    networking.nftables = {
      enable = lib.mkForce true;

      tables.cloudflare = {
        family = "inet";
        # Cloudflare IP ranges: https://www.cloudflare.com/ips
        content = ''
          set cloudflare_ipv4 {
            type ipv4_addr
            flags interval
            elements = {
              173.245.48.0/20,
              103.21.244.0/22,
              103.22.200.0/22,
              103.31.4.0/22,
              141.101.64.0/18,
              108.162.192.0/18,
              190.93.240.0/20,
              188.114.96.0/20,
              197.234.240.0/22,
              198.41.128.0/17,
              162.158.0.0/15,
              104.16.0.0/13,
              104.24.0.0/14,
              172.64.0.0/13,
              131.0.72.0/22
            }
          }

          set cloudflare_ipv6 {
            type ipv6_addr
            flags interval
            elements = {
              2400:cb00::/32,
              2606:4700::/32,
              2803:f800::/32,
              2405:b500::/32,
              2405:8100::/32,
              2a06:98c0::/29,
              2c0f:f248::/32
            }
          }

          chain input {
            type filter hook input priority 0; policy drop;

            # Allow loopback
            iifname "lo" accept

            # Allow established and related connections
            ct state established,related accept
            
            # Allow UDP for VPN handshakes (common ports)
            udp dport { 51820, 1637, 1320 } accept

            # Allow ICMP (Ping)
            ip protocol icmp accept
            ip6 nexthdr icmpv6 accept
            
            # Allow SSH (Port 5732), otherwise you might get locked out!
            tcp dport 5732 accept

            # Allow all traffic from internal container interfaces (Podman/CNI)
            # This allows containers to reach the host (DNS, Gateway)
            iifname "podman*" accept

            iifname "cni*" accept
            # Allow container subnet (fixes issues with non-podman* interface names)
            ip saddr 10.89.0.0/16 accept
            
            # Allow RFC1918 Private Networks (LAN, Containers, Link-Local)
            ${lib.optionalString cfg.allowLocalTraffic ''
              ip saddr 10.0.0.0/8 accept
              ip saddr 172.16.0.0/12 accept
              ip saddr 192.168.0.0/16 accept
            ''}
            ip saddr 169.254.0.0/16 accept
            
            # Public Ports (Open to everyone)
            ${lib.optionalString (cfg.publicPorts != [ ]) ''
              tcp dport { ${lib.concatStringsSep ", " (map toString cfg.publicPorts)} } accept
            ''}

            # Restricted Ports (Cloudflare only)
            ${lib.optionalString (cfg.restrictedPorts != [ ]) ''
              ip saddr @cloudflare_ipv4 tcp dport { ${lib.concatStringsSep ", " (map toString cfg.restrictedPorts)} } accept
              ip6 saddr @cloudflare_ipv6 tcp dport { ${lib.concatStringsSep ", " (map toString cfg.restrictedPorts)} } accept

              # Drop all other traffic to restricted ports
              tcp dport { ${lib.concatStringsSep ", " (map toString cfg.restrictedPorts)} } drop
            ''}
          }

          chain forward {
            type filter hook forward priority 0; policy drop;
            
            # Allow forwarding for containers (Internet Access)
            iifname "podman*" accept
            oifname "podman*" accept
            iifname "cni*" accept
            oifname "cni*" accept
            # Allow container subnet forwarding
            ip saddr 10.89.0.0/16 accept
            ip daddr 10.89.0.0/16 accept
            
            # Allow established/related forwarding
            ct state established,related accept
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }
        '';
      };

      tables.podman-mangle = lib.mkIf cfg.enablePodmanWorkaround {
        family = "ip";
        content = ''
          chain prerouting {
            type filter hook prerouting priority mangle; policy accept;
            iifname "podman*" meta mark set 0
          }
        '';
      };
    };
  };
}
