# Networking Configuration (Host-Specific)
# DNS-over-TLS is now in modules/system/dns-over-tls.nix
# Cloudflare firewall is now in modules/system/cloudflare-firewall.nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.hostName = "nixos";

  # Switch to systemd-networkd for bridging support
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;

  systemd.network = {
    netdevs."br0".netdevConfig = {
      Kind = "bridge";
      Name = "br0";
    };
    netdevs."br0".bridgeConfig = {
      STP = "no";
    };

    links."10-eth" = {
      matchConfig.Name = "enp4s0";
      linkConfig.MACAddressPolicy = "persistent";
    };

    networks."10-eth" = {
      matchConfig.Name = "enp4s0";
      networkConfig.Bridge = "br0";
    };

    networks."20-br0" = {
      matchConfig.Name = "br0";
      networkConfig = {
        DHCP = "yes";
        # Disable STP to prevent bridge topology re-calculations (fixes 15s delays)
        # STP = "no"; # Done in netdev
        IPv6PrivacyExtensions = "yes";
      };
    };
  };

  networking.enableIPv6 = true;

  # Basic firewall settings
  networking.firewall.enable = true;
  networking.nftables.enable = true;
  networking.firewall.checkReversePath = false; # Required for container routing

  # Container NAT (Restoring connectivity after removing VPN module)
  networking.nftables.tables."container-nat" = {
    family = "inet";
    content = ''
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        # Masquerade all container traffic going out via the bridge
        ip saddr 10.89.0.0/16 masquerade
      }
    '';
  };

  # Allow forwarding for containers (fixes DNS/Connectivity drops)
  networking.nftables.tables."container-filter" = {
    family = "inet";
    content = ''
      chain forward {
        type filter hook forward priority -100; policy accept;
        ip saddr 10.89.0.0/16 accept
        ip daddr 10.89.0.0/16 accept
      }
    '';
  };

  # Dynamic DNS for Cloudflare
  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    zone = "ashisgreat.xyz";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_api_key.path;
    domains = [
      "api.ashisgreat.xyz"
      "auth.ashisgreat.xyz"
      "chat.ashisgreat.xyz"
      "stream.ashisgreat.xyz"
      "stream-api.ashisgreat.xyz"
      "sonarr.ashisgreat.xyz"
      "radarr.ashisgreat.xyz"
      "prowlarr.ashisgreat.xyz"
      "torrent.ashisgreat.xyz"
      "jellyfin.ashisgreat.xyz"
      "jellyseer.ashisgreat.xyz"
      "jellyseerr.ashisgreat.xyz"
      "search.ashisgreat.xyz"
      "openclaw.ashisgreat.xyz"
    ];
    interval = "10min";
    usev6 = "disabled";
    usev4 = "cmdv4";
    extraConfig = ''
      cmdv4='${pkgs.curl}/bin/curl -s https://api.ipify.org'

      # Update IPv4 and IPv6 for root domain
      usev6=cmdv6
      cmdv6='${pkgs.curl}/bin/curl -s https://api64.ipify.org'
      ashisgreat.xyz

      # Revert to IPv4 only for subdomains appended below
      usev6=disabled
    '';
  };

  # Make ddclient use a static user for UID-based routing
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
    uid = 990;
  };
  users.groups.ddclient = {
    gid = 990;
  };

  # Static Nginx User override removed - using dynamic detection in vpn-routing.nix

  systemd.services.ddclient.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "ddclient";
    Group = "ddclient";
  };

  # Local Loopback for Hosted Services
  # Ensures the host can reach these domains even if VPN routing prevents public IP loopback
  networking.hosts = {
    "127.0.0.1" = [
      "ashisgreat.xyz"
      "api.ashisgreat.xyz"
      "search.ashisgreat.xyz"
      "chat.ashisgreat.xyz"
      "auth.ashisgreat.xyz"
      "stream.ashisgreat.xyz"
      "stream-api.ashisgreat.xyz"
      "sonarr.ashisgreat.xyz"
      "radarr.ashisgreat.xyz"
      "prowlarr.ashisgreat.xyz"
      "torrent.ashisgreat.xyz"
      "jellyfin.ashisgreat.xyz"
      "jellyseer.ashisgreat.xyz"
      "jellyseerr.ashisgreat.xyz"
      "openclaw.ashisgreat.xyz"
    ];
  };
}
