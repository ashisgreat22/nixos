{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.authelia.instances.main = {
    enable = false;

    # Secrets
    secrets = {
      jwtSecretFile = config.sops.secrets.authelia_jwt_secret.path;
      storageEncryptionKeyFile = config.sops.secrets.authelia_storage_encryption_key.path;
      sessionSecretFile = config.sops.secrets.authelia_session_secret.path;
    };

    settings = {
      theme = "dark";
      default_2fa_method = "totp";

      server = {
        address = "127.0.0.1:9099";
        disable_healthcheck = false;
      };

      log = {
        level = "info";
        format = "text";
      };

      totp = {
        issuer = "ashisgreat.xyz";
      };

      authentication_backend = {
        file = {
          path = "/var/lib/authelia-main/users_database.yml";
          watch = true;
        };
      };

      access_control = {
        default_policy = "deny";
        rules = [
          # Public access to Authelia itself
          {
            domain = "auth.ashisgreat.xyz";
            policy = "bypass";
          }
          # Protected services (2FA required)
          {
            domain = [
              "sonarr.ashisgreat.xyz"
              "radarr.ashisgreat.xyz"
              "prowlarr.ashisgreat.xyz"
              "jellyfin.ashisgreat.xyz" # Jellyfin can use its own auth, but wrapping it adds 2FA
              "torrent.ashisgreat.xyz"
              "jellyseer.ashisgreat.xyz" # Note: Typo in services.nix maintained here, check if corrected in Caddy
            ];
            policy = "two_factor";
          }
        ];
      };

      session = {
        name = "authelia_session";
        domain = "ashisgreat.xyz";
        same_site = "lax";
        expiration = "1h";
        inactivity = "5m";
        remember_me = "1M";
      };

      regulation = {
        max_retries = 3;
        find_time = "2m";
        ban_time = "5m";
      };

      storage = {
        local = {
          path = "/var/lib/authelia-main/db.sqlite3";
        };
      };

      notifier = {
        filesystem = {
          filename = "/var/lib/authelia-main/notification.txt";
        };
      };
    };
  };

  # Ensure the directory exists for users_database.yml
  systemd.tmpfiles.rules = [
    "d /var/lib/authelia-main 0700 authelia-main authelia-main -"
    "f /var/lib/authelia-main/users_database.yml 0600 authelia-main authelia-main -"
  ];
}
