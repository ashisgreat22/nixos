{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.sched-ext;
in
{
  options.myModules.sched-ext = {
    enable = lib.mkEnableOption "sched-ext (scx) schedulers";
    
    scheduler = lib.mkOption {
      type = lib.types.enum [ "scx_lavd" "scx_rusty" "scx_bpfland" ];
      default = "scx_lavd";
      description = "The scx scheduler to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install the schedulers
    environment.systemPackages = [ pkgs.scx ];

    # Systemd service to run the scheduler
    systemd.services.scx = {
      description = "sched-ext scheduler (${cfg.scheduler})";
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.scx ];
      serviceConfig = {
        ExecStart = "${pkgs.scx}/bin/${cfg.scheduler}";
        Restart = "always";
        RestartSec = "3";
        Nice = -20;
      };
    };
  };
}
