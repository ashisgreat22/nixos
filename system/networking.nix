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

    networks."10-eth" = {
      matchConfig.Name = "enp4s0";
      networkConfig.Bridge = "br0";
    };

    networks."20-br0" = {
      matchConfig.Name = "br0";
      networkConfig = {
        DHCP = "yes";
        # Ensure DNS/Gateway is accepted
        IPv6PrivacyExtensions = "yes";
      };
    };
  };

  networking.enableIPv6 = false;

  # Disable IPv6 via sysctl
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
    "net.ipv6.conf.lo.disable_ipv6" = 1;
  };

  # Basic firewall settings (Cloudflare rules are in the module)
  networking.firewall.enable = false;

  # Dynamic DNS for Cloudflare
  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    zone = "ashisgreat.xyz";
    username = "token";
    passwordFile = config.sops.secrets.cloudflare_api_key.path;
    domains = [
      "api.ashisgreat.xyz"
      "chat.ashisgreat.xyz"
      "stream.ashisgreat.xyz"
      "stream-api.ashisgreat.xyz"
    ];
    interval = "10min";
    usev6 = "disabled";
    usev4 = "cmdv4";
    extraConfig = "cmdv4='${pkgs.curl}/bin/curl -s https://api.ipify.org'";
  };
}
