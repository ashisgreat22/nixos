{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.wireproxy;
in
{
  options.myModules.wireproxy = {
    enable = lib.mkEnableOption "wireproxy SOCKS5 proxy";
    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:1080";
      description = "The address and port to bind the SOCKS5 proxy to.";
    };
    endpointIP = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the WireGuard endpoint IP.";
    };
    endpointPort = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Override the WireGuard endpoint port.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.wireproxy ];

    sops.templates."wireproxy.conf" = {
      group = "keys";
      mode = "0440";
      content =
        let
          endpointIP =
            if cfg.endpointIP != null then cfg.endpointIP else config.sops.placeholder.wireguard_endpoint_ip;
          endpointPort =
            if cfg.endpointPort != null then
              toString cfg.endpointPort
            else
              config.sops.placeholder.wireguard_endpoint_port;
        in
        ''
          [Interface]
          PrivateKey = ${config.sops.placeholder.wireguard_private_key}
          Address = ${config.sops.placeholder.wireguard_addresses}, ${config.sops.placeholder.wireguard6_adresses}
          DNS = 9.9.9.9, 149.112.112.112, ${config.sops.placeholder.wireguard_dns}, ${config.sops.placeholder.wireguard6_dns}
          MTU = 1420

          [Peer]
          PublicKey = ${config.sops.placeholder.wireguard_public_key}
          Endpoint = earth3.vpn.airdns.org:1637 
          AllowedIPs = 0.0.0.0/0, ::/0
          PresharedKey = ${config.sops.placeholder.wireguard_preshared_key}
          PersistentKeepalive = 25

          [Socks5]
          BindAddress = ${cfg.bindAddress}
        '';
    };

    systemd.services.wireproxy = {
      description = "User-space WireGuard SOCKS5 proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.wireproxy}/bin/wireproxy -c ${config.sops.templates."wireproxy.conf".path}";

        DynamicUser = true;
        SupplementaryGroups = [ "keys" ];
        Restart = "on-failure";
        RestartSec = "5s";

        # Hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # CapabilityBoundingSet = [
        #   "CAP_NET_ADMIN"
        #   "CAP_NET_RAW"
        # ];
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        MemoryDenyWriteExecute = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
      };
    };
  };
}
