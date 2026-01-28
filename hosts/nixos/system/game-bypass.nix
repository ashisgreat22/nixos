{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Namespace setup for Game Bypass
  systemd.services.game-bypass-netns = {
    description = "Game Bypass Network Namespace (Direct Internet)";
    wants = [ "network.target" ];
    after = [ "network.target" ];
    requiredBy = [ "multi-user.target" ];

    path = [
      pkgs.iproute2
      pkgs.kmod
      pkgs.util-linux # for nsenter
      pkgs.dhcpcd
    ];

    script = ''
      NAME="physical"
      VETH_HOST="veth-game"
      VETH_NS="eth0"
      BRIDGE="br0"

      # 1. Create Namespace if not exists
      if ! ip netns list | grep -q "$NAME"; then
        ip netns add "$NAME"
      fi

      # 2. Setup Veth Pair
      # Cleanup previous
      ip link delete "$VETH_HOST" 2>/dev/null || true

      # Create pair
      ip link add "$VETH_HOST" type veth peer name "$VETH_NS-tmp"

      # Host side: Attach to Bridge
      ip link set "$VETH_HOST" master "$BRIDGE"
      ip link set "$VETH_HOST" up

      # Client side: Move to NS
      ip link set "$VETH_NS-tmp" netns "$NAME"

      # 3. Configure Inside Namespace
      # Rename to eth0
      ip netns exec "$NAME" ip link set "$VETH_NS-tmp" name "$VETH_NS"
      ip netns exec "$NAME" ip link set "$VETH_NS" up
      ip netns exec "$NAME" ip link set lo up

      # 4. DHCP
      # Run dhcpcd inside the namespace
      # We use -4 for IPv4 only if desired, or just standard
      ip netns exec "$NAME" dhcpcd --nobackground "$VETH_NS" &

      # 5. DNS (Use Google/Cloudflare directly)
      mkdir -p /etc/netns/"$NAME"
      echo "nameserver 1.1.1.1" > /etc/netns/"$NAME"/resolv.conf
      echo "nameserver 8.8.8.8" >> /etc/netns/"$NAME"/resolv.conf
    '';

    # We use oneshot to just launch dhcpcd
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };
  };

  # Wrapper script to launch apps in the bypass
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "game-bypass" ''
      exec doas ip netns exec physical sudo -u ${config.users.users.ashie.name} -E -- "$@"
    '')
  ];

  # Security wrapper permissions
  security.doas.extraRules = [
    {
      users = [ "ashie" ];
      cmd = "/run/current-system/sw/bin/ip";
      args = [
        "netns"
        "exec"
        "physical"
        "sudo"
        "-u"
        "ashie"
        "-E"
        "--"
      ];
      noPass = true;
      keepEnv = true;
    }
  ];

  # Also need sudo rules?
  # "sudo -u ashie" inside the namespace might prompt for password if not configured.
  # Usually user running sudo to switch to themselves needs no password if standard setup,
  # OR we can just use setpriv/su if we are already root (which ip netns exec is).
  # Wait, `ip netns exec` runs as root.
  # So we are root inside the NS. We then drop privileges to 'ashie'.
  # `sudo -u ashie` works fine if we are root.

}
