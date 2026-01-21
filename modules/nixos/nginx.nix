# Nginx with Cloudflare ACME Module
# Provides: Secure Nginx setup with automated SSL handling via Cloudflare DNS challenge

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.nginx;
in
{
  options.myModules.nginx = {
    enable = lib.mkEnableOption "Nginx with Cloudflare ACME";
  };

  config = lib.mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      defaults.email = "mails@ashisgreat.xyz";

      certs."ashisgreat.xyz" = {
        domain = "ashisgreat.xyz";
        extraDomainNames = [ "*.ashisgreat.xyz" ];
        dnsProvider = "cloudflare";
        group = "nginx";
        environmentFile = config.sops.templates."cloudflare-acme.env".path;
        # Reload Nginx when certs change
        reloadServices = [ "nginx" ];
      };
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # SSL Hardening
      sslProtocols = "TLSv1.2 TLSv1.3";
      sslCiphers = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";

      # Use the wildcard cert by default for these domains
      commonHttpConfig = ''
        # HSTS 1 year
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      '';
    };
  };
}
