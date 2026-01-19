{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Ensure iproute2 is available
  environment.systemPackages = [ pkgs.iproute2 ];

  systemd.services.vpn-netns = {
    description = "VPN Network Namespace Setup";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    requiredBy = [ "multi-user.target" ];

    path = [
      pkgs.iproute2
      pkgs.wireguard-tools
      pkgs.kmod
    ];

    script = ''
      # 1. Create Namespace if not exists
      if ! ip netns list | grep -q "vpn"; then
        ip netns add vpn
      fi

      # 2. Cleanup & Create WireGuard Interface
      # Delete if exists INSIDE namespace (from previous run)
      ip netns exec vpn ip link delete wg0 2>/dev/null || true

      # Delete if exists in default namespace
      ip link delete wg0 2>/dev/null || true
      ip link add wg0 type wireguard
      ip link set mtu 1320 dev wg0

      # 3. Move to Namespace
      ip link set wg0 netns vpn

      # 4. Configure WireGuard (INSIDE NAMESPACE)
      # We read secrets from the sops-rendered files
      PRIVATE_KEY=$(cat ${config.sops.secrets.wireguard_private_key.path})
      PEER_KEY=$(cat ${config.sops.secrets.wireguard_public_key.path})
      ENDPOINT_IP=$(cat ${config.sops.secrets.wireguard_endpoint_ip.path})
      ENDPOINT_PORT=$(cat ${config.sops.secrets.wireguard_endpoint_port.path})
      ADDRESS=$(cat ${config.sops.secrets.wireguard_addresses.path})
      PRESHARED_KEY=$(cat ${config.sops.secrets.wireguard_preshared_key.path})

      # Pass private key via stdin to file
      echo "$PRIVATE_KEY" > /run/wg0.key
      chmod 600 /run/wg0.key

      # Setup interface inside netns
      ip netns exec vpn wg set wg0 \
        private-key /run/wg0.key \
        peer "$PEER_KEY" \
        preshared-key <(echo "$PRESHARED_KEY") \
        endpoint "$ENDPOINT_IP:$ENDPOINT_PORT" \
        allowed-ips 0.0.0.0/0

      rm /run/wg0.key

      # Assign IP Address
      ip netns exec vpn ip addr add "$ADDRESS" dev wg0

      # Set MTU (Optimized for VPN to avoid fragmentation)
      ip netns exec vpn ip link set mtu 1320 dev wg0

      # Bring Up
      ip netns exec vpn ip link set wg0 up
      ip netns exec vpn ip link set lo up

      # Set Default Route
      ip netns exec vpn ip route add default dev wg0

      # 5. DNS (Optional - force Google/Cloudflare inside namespace)
      mkdir -p /etc/netns/vpn
      echo "nameserver 1.1.1.1" > /etc/netns/vpn/resolv.conf
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };
  };

  # Allow user 'ashie' to run the namespace launcher without password
  security.doas.extraRules = [
    {
      users = [ "ashie" ];
      cmd = "/run/current-system/sw/bin/ip";
      args = [
        "netns"
        "exec"
        "vpn"
        "doas"
        "-u"
        "ashie"
        "--"
      ]; # Permit the specific chain
      noPass = true;
    }
    # Allow running the script itself
    {
      users = [ "ashie" ];
      cmd = "/home/ashie/nixos/scripts/launch-vpn-app.sh";
      noPass = true;
      keepEnv = true;
    }
  ];
}
