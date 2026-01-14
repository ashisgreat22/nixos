{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.myModules.niri;
in
{
  options.myModules.niri = {
    enable = lib.mkEnableOption "Niri configuration";

    keyboardLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
    };

    keyboardVariant = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    keyboardOptions = lib.mkOption {
      type = lib.types.str;
      default = "caps:escape";
    };

    primaryMonitor = lib.mkOption {
      type = lib.types.str;
      default = "DP-1";
    };

    primaryResolution = lib.mkOption {
      type = lib.types.str;
      default = "2560x1440@165";
    };

    secondaryMonitor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    secondaryResolution = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080@60";
    };

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    launcher = lib.mkOption {
      type = lib.types.str;
      default = "noctalia-shell ipc call launcher toggle";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.niri.packages.${pkgs.system}.niri
      inputs.niri.packages.${pkgs.system}.niri
      pkgs.xwayland-satellite
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.lxqt.lxqt-policykit
      pkgs.libnotify
      pkgs.swww
    ];

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config.common.default = [
        "gtk"
        "gnome"
      ];
    };

    systemd.user.services.xwayland-satellite = {
      Unit = {
        Description = "Xwayland Satellite (Rootless Xwayland Bridge)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
        Restart = "always";
        RestartSec = "10";

        # Security Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    xdg.configFile."niri/config.kdl".text = ''
      input {
          keyboard {
              xkb {
                  layout "${cfg.keyboardLayout}"
                  variant "${cfg.keyboardVariant}"
                  options "${cfg.keyboardOptions}"
              }
          }
          mouse {
              accel-profile "flat"
          }
          focus-follows-mouse
      }

      environment {
          GTK_THEME "catppuccin-mocha-mauve-standard"
          GTK_THEME "catppuccin-mocha-mauve-standard"
          QT_QPA_PLATFORMTHEME "gtk3"
          QT_STYLE_OVERRIDE "kvantum"
          XCURSOR_THEME "Bibata-Modern-Ice"
          XCURSOR_SIZE "24"
      }

      prefer-no-csd


      output "${cfg.primaryMonitor}" {
          mode "${cfg.primaryResolution}"
          scale 1.0
          position x=1920 y=0
      }

      ${lib.optionalString (cfg.secondaryMonitor != null) ''
        output "${cfg.secondaryMonitor}" {
            mode "${cfg.secondaryResolution}"
            scale 1.0
            position x=0 y=0
        }
      ''}

      layout {
          gaps 8
          center-focused-column "never"

          preset-column-widths {
              proportion 0.33333
              proportion 0.5
              proportion 0.66667
          }

          default-column-width { proportion 0.5; }

          focus-ring {
              off
          }
      }

      spawn-at-startup "swww-daemon"
      spawn-at-startup "bash" "-c" "sleep 1; swww img /home/ashie/Pictures/Wallpapers/chill-mario.gif"

      spawn-at-startup "bash" "-c" "sleep 2; dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP; ${
        inputs.noctalia.packages.${pkgs.system}.default
      }/bin/noctalia-shell >> /tmp/noctalia.log 2>&1"

      binds {
          Mod+Return { spawn "${cfg.terminal}"; }
          Mod+D { spawn "sh" "-c" "${cfg.launcher}"; }
          Mod+Q { close-window; }
          Mod+E { spawn "nautilus"; }
          Mod+F { fullscreen-window; }
          Mod+M { maximize-column; }
          Mod+Space { switch-preset-column-width; }

          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }

          Mod+WheelScrollDown { focus-column-right; }
          Mod+WheelScrollUp { focus-column-left; }
          Mod+Left { focus-column-left; }
          Mod+Right { focus-column-right; }
          Mod+Up { focus-window-up; }
          Mod+Down { focus-window-down; }
          Mod+H { focus-column-left; }
          Mod+L { focus-column-right; }
          Mod+K { focus-window-up; }
          Mod+J { focus-window-down; }

          Mod+Shift+Left { move-column-left; }
          Mod+Shift+Right { move-column-right; }
          Mod+Shift+Up { move-window-up; }
          Mod+Shift+Down { move-window-down; }
          Mod+Shift+H { move-column-left; }
          Mod+Shift+L { move-column-right; }
          Mod+Shift+K { move-window-up; }
          Mod+Shift+J { move-window-down; }

          Mod+Ctrl+1 { move-column-to-workspace 1; }
          Mod+Ctrl+2 { move-column-to-workspace 2; }
          Mod+Ctrl+3 { move-column-to-workspace 3; }
          Mod+Ctrl+4 { move-column-to-workspace 4; }
          Mod+Ctrl+5 { move-column-to-workspace 5; }
          Mod+Ctrl+6 { move-column-to-workspace 6; }
          Mod+Ctrl+7 { move-column-to-workspace 7; }
          Mod+Ctrl+8 { move-column-to-workspace 8; }
          Mod+Ctrl+9 { move-column-to-workspace 9; }

          Mod+BracketLeft { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }
          Mod+C { center-column; }

          Mod+Minus { set-column-width "-10%"; }
          Mod+Equal { set-column-width "+10%"; }

          Mod+Shift+E { quit; }
          Print { spawn "sh" "-c" "grim -g \"$(slurp)\" - | wl-copy"; }

          // Browsers
          Mod+W { spawn "firefox"; }
          Mod+Alt+W { spawn "tor-browser-vpn-podman"; }
          Mod+Shift+W { spawn "brave"; }
          Mod+Alt+Return { spawn "kitty-vpn-podman"; }

          // Media
          XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "-l" "1.5" "@DEFAULT_AUDIO_SINK@" "5%+"; }
          XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
          XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
          XF86AudioPlay { spawn "playerctl" "play-pause"; }
          XF86AudioNext { spawn "playerctl" "next"; }
          XF86AudioPrev { spawn "playerctl" "previous"; }
      }

      window-rule {
          geometry-corner-radius 12
          clip-to-geometry true
      }

      window-rule {
          match app-id="^Tor Browser$"
          open-floating true
      }
    '';
  };
}
