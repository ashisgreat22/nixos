{
  config,
  lib,
  pkgs,
  ...
}:

{
  networking.wg-quick.interfaces = {
    wg0 = {
      address = [ "10.66.219.165/32" ]; # Fallback, should ideally come from secret but wg-quick needs it here or in config
      # We will rely on the config file generation to include the address if possible,
      # but nixos module usually requires 'address' or 'configFile'.
      # Since we are using secrets for everything, we might need a script or careful usage of configFile.

      # Better approach with sops: use the declarative config but read secrets from file for keys.
      # However, 'address' usually isn't secret.
      # In vpn-namespace.nix: ADDRESS=$(cat ${config.sops.secrets.wireguard_addresses.path})

      # Valid approach for secrets in wg-quick:
      # Use configFile pointing to a secret file, OR use normal config with privateKeyFile.

      autostart = true;
      dns = [ "1.1.1.1" ]; # Force DNS through VPN (or public DNS)
      privateKeyFile = config.sops.secrets.wireguard_private_key.path;

      peers = [
        {
          publicKey = "KPj/q9j/..."; # We need the public key here.
          # PROB: The user's vpn-namespace.nix was reading PEER_KEY from a secret.
          # NixOS wg-quick module expects publicKey as a string literal in the nix config, usually.
          # If the peer public key is secret, we can't easily put it in nix store (it ends up world readable).
          # BUT: Public keys are generally safe to be public.
          # However, since the user has it in sops, they might want to keep it secret.

          # ALTERNATIVE: Use `configFile` option and generate the whole config from secrets at runtime.
          # But `networking.wg-quick.interfaces.<name>.configFile` expects a path.

          # Let's write a script to generate the config file from secrets and start it.
          # actually, the `networking.wg-quick` module is just a wrapper around systemd services.

          # Let's try to stick to the module if possible.
          # If we can't, we can write a systemd service just like vpn-namespace.nix but for the main netns.
        }
      ];
    };
  };

  # RE-EVALUATION:
  # Since all WireGuard parameters (Addresses, Endpoint, Keys) are in sops secrets,
  # trying to use `networking.wg-quick.interfaces` is clumsy because it expects static values for non-secrets.
  # We should create a systemd service that constructs the config and runs wg-quick.

  systemd.services.wg-quick-wg0 = {
    description = "WireGuard Tunnel wg0";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.wireguard-tools
      pkgs.bash
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wg0-up" ''
        # Generate Config
        PRIVATE_KEY=$(cat ${config.sops.secrets.wireguard_private_key.path})
        PEER_KEY=$(cat ${config.sops.secrets.wireguard_public_key.path})
        ENDPOINT_IP=$(cat ${config.sops.secrets.wireguard_endpoint_ip.path})
        ENDPOINT_PORT=$(cat ${config.sops.secrets.wireguard_endpoint_port.path})
        ADDRESS=$(cat ${config.sops.secrets.wireguard_addresses.path})
        PRESHARED_KEY=$(cat ${config.sops.secrets.wireguard_preshared_key.path})

        cat > /run/wg0.conf <<EOF
        [Interface]
        Address = $ADDRESS
        PrivateKey = $PRIVATE_KEY
        DNS = 1.1.1.1

        [Peer]
        PublicKey = $PEER_KEY
        PresharedKey = $PRESHARED_KEY
        Endpoint = $ENDPOINT_IP:$ENDPOINT_PORT
        AllowedIPs = 0.0.0.0/0
        EOF

        chmod 600 /run/wg0.conf
        ${pkgs.wireguard-tools}/bin/wg-quick up /run/wg0.conf
      '';
      ExecStop = "${pkgs.wireguard-tools}/bin/wg-quick down /run/wg0.conf";
    };
  };
}
