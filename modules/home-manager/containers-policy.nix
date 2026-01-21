{ pkgs, ... }:

{
  # Rootless podman policy configuration
  # Required for user-level podman to pull container images
  home.file.".config/containers/policy.json".text = builtins.toJSON {
    default = [ { type = "insecureAcceptAnything"; } ];
    transports = {
      docker-daemon = {
        "" = [ { type = "insecureAcceptAnything"; } ];
      };
    };
  };
}
