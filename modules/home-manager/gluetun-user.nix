# Gluetun User Service Module (Home Manager)
# Provides: Rootless Gluetun VPN container as user systemd service
#
# Usage:
#   myModules.gluetunUser = {
#     enable = true;
#     environmentFile = "/run/secrets/rendered/gluetun.env";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.gluetunUser;
in
{
  options.myModules.gluetunUser = {
    enable = lib.mkEnableOption "Rootless Gluetun VPN container service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "qmcgaw/gluetun:latest";
      description = "Gluetun container image";
    };

    webPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Web UI port for Gluetun";
    };

    environmentFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to environment file with VPN credentials";
    };

    secretsDir = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets";
      description = "Path to secrets directory";
    };

    dnsAddress = lib.mkOption {
      type = lib.types.str;
      default = "9.9.9.9";
      description = "DNS server address for VPN";
    };

    extraPorts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra ports to map (e.g. ['3000:80'])";
    };

    wireguardMtu = lib.mkOption {
      type = lib.types.int;
      default = 1280;
      description = "WireGuard MTU setting";
    };

    keepaliveInterval = lib.mkOption {
      type = lib.types.str;
      default = "15s";
      description = "WireGuard persistent keepalive interval";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.gluetun = {
      Unit = {
        Description = "Gluetun VPN Container (Rootless)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Restart = "always";
        ExecStartPre = [
          "-${pkgs.podman}/bin/podman system migrate"
          "-${pkgs.podman}/bin/podman stop gluetun"
        ];
        ExecStart = ''
          ${pkgs.podman}/bin/podman run --rm --replace --name gluetun \
            --cap-add=NET_ADMIN \
            --device=/dev/net/tun \
            --sysctl=net.ipv4.conf.all.src_valid_mark=1 \
            --add-host=host.containers.internal:host-gateway \
            -v ${cfg.environmentFile}:${cfg.environmentFile}:ro \
            -v ${cfg.secretsDir}:${cfg.secretsDir}:ro \
            -p 127.0.0.1:${toString cfg.webPort}:8080 \
            ${lib.concatMapStringsSep " " (p: "-p ${p}") cfg.extraPorts} \
            -e VPN_SERVICE_PROVIDER=custom \
            -e VPN_TYPE=wireguard \
            -e WIREGUARD_IMPLEMENTATION=userspace \
            -e WIREGUARD_PRIVATE_KEY_SECRETFILE=${cfg.secretsDir}/wireguard_private_key \
            -e WIREGUARD_PRESHARED_KEY_SECRETFILE=${cfg.secretsDir}/wireguard_preshared_key \
            -e WIREGUARD_ADDRESSES_SECRETFILE=${cfg.secretsDir}/wireguard_addresses \
            -e WIREGUARD_PUBLIC_KEY=''${WIREGUARD_PUBLIC_KEY} \
            -e WIREGUARD_ENDPOINT_IP=''${WIREGUARD_ENDPOINT_IP} \
            -e WIREGUARD_ENDPOINT_PORT=''${WIREGUARD_ENDPOINT_PORT} \
            -e WIREGUARD_MTU=1280 \
            -e WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL=15s \
            -e DNS_ADDRESS=${cfg.dnsAddress} \
            -e DOT=off \
            -e DOT_CACHING=on \
            -e HEALTH_RESTART_VPN=off \
            -e LOG_LEVEL=info \
            -e FIREWALL_VPN_INPUT_PORTS=4000,3001,3000,9090,36630 \
            ${cfg.image}
        '';
        EnvironmentFile = [ cfg.environmentFile ];
        ExecStop = "${pkgs.podman}/bin/podman stop gluetun";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
