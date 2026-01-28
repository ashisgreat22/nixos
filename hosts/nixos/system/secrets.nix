{
  config,
  pkgs,
  inputs,
  ...
}:

{
  sops.defaultSopsFile = ../../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # sops.age.keyFile = "/home/ashie/.config/sops/age/keys.txt";
  # WireGuard / Gluetun secrets
  sops.secrets.wireguard_private_key = {
    owner = "ashie";
  };
  sops.secrets.wireguard_public_key = {
    owner = "ashie";
  };
  sops.secrets.wireguard_endpoint_ip = {
    owner = "ashie";
  };
  sops.secrets.wireguard_endpoint_port = {
    owner = "ashie";
  };
  sops.secrets.wireguard_addresses = {
    owner = "ashie";
  };
  sops.secrets.wireguard_preshared_key = {
    owner = "ashie";
  };

  sops.secrets.wireguard_dns = {
    owner = "ashie";
  };

  sops.secrets.open_webui_env = {
    owner = "ashie";
  };

  sops.templates."gluetun.env" = {
    owner = "ashie";
    content = ''
      WIREGUARD_PUBLIC_KEY=${config.sops.placeholder.wireguard_public_key}
      WIREGUARD_ENDPOINT_IP=${config.sops.placeholder.wireguard_endpoint_ip}
      WIREGUARD_ENDPOINT_PORT=${config.sops.placeholder.wireguard_endpoint_port}
      WIREGUARD_PRIVATE_KEY=${config.sops.placeholder.wireguard_private_key}
      WIREGUARD_ADDRESSES=${config.sops.placeholder.wireguard_addresses}
      WIREGUARD_PRESHARED_KEY=${config.sops.placeholder.wireguard_preshared_key}
      DNS_ADDRESS=${config.sops.placeholder.wireguard_dns}
      WIREGUARD_MTU=1320
      VPN_SERVICE_PROVIDER=custom
      VPN_TYPE=wireguard
      VPN_PORT_FORWARDING=off
    '';
  };

  # Cloudflare secrets
  sops.secrets.cloudflare_api_key = { };

  # Cloudflare ACME Environment File
  sops.templates."cloudflare-acme.env" = {
    content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.cloudflare_api_key}
    '';
  };

  # Unified API Key
  sops.secrets.master_api_key = {
    owner = "ashie";
  };

  sops.templates."api_key.env" = {
    owner = "ashie";
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder.master_api_key}
      API_KEY=${config.sops.placeholder.master_api_key}
      KEY=${config.sops.placeholder.master_api_key}
      JWT_SECRET=${config.sops.placeholder.jwt_secret}
    '';
  };

  sops.secrets.jwt_secret = {
    owner = "ashie";
  };

  sops.secrets.hashed_password = {
    neededForUsers = true;
  };

  # Nixflix secrets
  sops.secrets.nixflix_password = { };
  sops.secrets.sonarr_api_key = { };
  sops.secrets.radarr_api_key = { };
  sops.secrets.prowlarr_api_key = { };

  # Authelia Secrets
  #  sops.secrets.authelia_jwt_secret = {
  #    owner = "authelia-main";
  #  };
  #  sops.secrets.authelia_session_secret = {
  #    owner = "authelia-main";
  #  };
  #  sops.secrets.authelia_storage_encryption_key = {
  #    owner = "authelia-main";
  #  };
}
