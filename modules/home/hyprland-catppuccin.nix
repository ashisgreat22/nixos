# Hyprland Catppuccin Theme Module (Home Manager)
# Provides: Catppuccin-themed Hyprland with animations and keybinds
#
# Usage:
#   myModules.hyprlandCatppuccin = {
#     enable = true;
#     keyboardLayout = "de";
#     primaryMonitor = "DP-2";
#     secondaryMonitor = "HDMI-A-1";
#   };

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myModules.hyprlandCatppuccin;
in
{
  options.myModules.hyprlandCatppuccin = {
    enable = lib.mkEnableOption "Catppuccin-themed Hyprland configuration";

    keyboardLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "Keyboard layout";
    };

    keyboardVariant = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Keyboard variant (e.g., 'nodeadkeys')";
    };

    keyboardModel = lib.mkOption {
      type = lib.types.str;
      default = "pc104";
      description = "Keyboard model (e.g., 'pc104' or 'pc105')";
    };

    capsToEscape = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Remap Caps Lock to Escape";
    };

    primaryMonitor = lib.mkOption {
      type = lib.types.str;
      default = "DP-1";
      description = "Primary monitor name";
    };

    primaryResolution = lib.mkOption {
      type = lib.types.str;
      default = "2560x1440@165";
      description = "Primary monitor resolution and refresh rate";
    };

    secondaryMonitor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Secondary monitor name (null to disable)";
    };

    secondaryResolution = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080@60";
      description = "Secondary monitor resolution";
    };

    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
      description = "Default terminal emulator";
    };

    fileManager = lib.mkOption {
      type = lib.types.str;
      default = "nautilus";
      description = "Default file manager";
    };

    launcher = lib.mkOption {
      type = lib.types.str;
      default = "noctalia-shell ipc call launcher toggle";
      description = "Application launcher";
    };

    gapsIn = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Inner gaps between windows";
    };

    gapsOut = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "Outer gaps around windows";
    };

    borderSize = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Window border size";
    };

    rounding = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Window corner rounding";
    };

    enableBlur = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable window blur effect";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;

      settings = {
        input = {
          kb_layout = cfg.keyboardLayout;
          kb_variant = cfg.keyboardVariant;
          kb_model = cfg.keyboardModel;
          kb_options = lib.mkIf cfg.capsToEscape "caps:escape";
          accel_profile = "flat";
        };

        exec-once = [
          "gnome-keyring-daemon --start --components=secrets,pkcs11"
          "lxqt-policykit-agent"
          "swww-daemon"
          "swww img /home/ashie/Pictures/Wallpapers/chill-mario.gif"
          "noctalia-shell"
        ];

        bind = [
          "SUPER, Return, exec, ${cfg.terminal}"
          "SUPER, Q, killactive"
          "SUPER, E, exec, ${cfg.fileManager}"
          "SUPER, 1, exec, ~/.config/hypr/ws-go.sh workspace 1"
          "SUPER, 2, exec, ~/.config/hypr/ws-go.sh workspace 2"
          "SUPER, 3, exec, ~/.config/hypr/ws-go.sh workspace 3"
          "SUPER, 4, exec, ~/.config/hypr/ws-go.sh workspace 4"
          "SUPER, 5, exec, ~/.config/hypr/ws-go.sh workspace 5"
          "SUPER, 6, exec, ~/.config/hypr/ws-go.sh workspace 6"
          "SUPER, 7, exec, ~/.config/hypr/ws-go.sh workspace 7"
          "SUPER, 8, exec, ~/.config/hypr/ws-go.sh workspace 8"
          "SUPER, 9, exec, ~/.config/hypr/ws-go.sh workspace 9"
          "SUPER, 0, exec, ~/.config/hypr/ws-go.sh workspace 0"

          "SUPER_CTRL, 1, exec, ~/.config/hypr/ws-go.sh movetoworkspace 1"
          "SUPER_CTRL, 2, exec, ~/.config/hypr/ws-go.sh movetoworkspace 2"
          "SUPER_CTRL, 3, exec, ~/.config/hypr/ws-go.sh movetoworkspace 3"
          "SUPER_CTRL, 4, exec, ~/.config/hypr/ws-go.sh movetoworkspace 4"
          "SUPER_CTRL, 5, exec, ~/.config/hypr/ws-go.sh movetoworkspace 5"
          "SUPER_CTRL, 6, exec, ~/.config/hypr/ws-go.sh movetoworkspace 6"
          "SUPER_CTRL, 7, exec, ~/.config/hypr/ws-go.sh movetoworkspace 7"
          "SUPER_CTRL, 8, exec, ~/.config/hypr/ws-go.sh movetoworkspace 8"
          "SUPER_CTRL, 9, exec, ~/.config/hypr/ws-go.sh movetoworkspace 9"
          "SUPER_CTRL, 0, exec, ~/.config/hypr/ws-go.sh movetoworkspace 0"

          "SUPER, F, fullscreen, 0"
          "SUPER, SPACE, togglefloating"
          # Browsers (all via isolated Podman containers)
          "SUPER, W, exec, firefox-vpn-podman"
          "SUPER ALT, W, exec, tor-browser-vpn-podman"
          "SUPER ALT, Return, exec, kitty-vpn-podman"
          "SUPER SHIFT, W, exec, thorium-vpn-podman"

          # Media Controls
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ];

        bindm = [
          "SUPER, mouse:272, movewindow"
          "SUPER, mouse:273, resizewindow"
        ];

        monitor = [
          "${cfg.primaryMonitor}, ${cfg.primaryResolution}, 1920x0, 1"
        ]
        ++ lib.optional (
          cfg.secondaryMonitor != null
        ) "${cfg.secondaryMonitor}, ${cfg.secondaryResolution}, 0x0, 1";

        workspace = [
          "1, monitor:${cfg.primaryMonitor}"
          "2, monitor:${cfg.primaryMonitor}"
          "3, monitor:${cfg.primaryMonitor}"
          "4, monitor:${cfg.primaryMonitor}"
          "5, monitor:${cfg.primaryMonitor}"
          "6, monitor:${cfg.primaryMonitor}"
          "7, monitor:${cfg.primaryMonitor}"
          "8, monitor:${cfg.primaryMonitor}"
          "9, monitor:${cfg.primaryMonitor}"
          "10, monitor:${cfg.primaryMonitor}"
        ]
        ++ lib.optionals (cfg.secondaryMonitor != null) [
          "12, monitor:${cfg.secondaryMonitor}"
          "13, monitor:${cfg.secondaryMonitor}"
          "14, monitor:${cfg.secondaryMonitor}"
          "15, monitor:${cfg.secondaryMonitor}"
          "16, monitor:${cfg.secondaryMonitor}"
          "17, monitor:${cfg.secondaryMonitor}"
          "18, monitor:${cfg.secondaryMonitor}"
          "19, monitor:${cfg.secondaryMonitor}"
          "20, monitor:${cfg.secondaryMonitor}"
        ];
      };

      extraConfig = ''
        bind = Super, Super_L, exec, ${cfg.launcher}
        windowrulev2 = float, class:^(Tor Browser)$
        env = HYPRCURSOR_THEME,"Future-Cyan-Hyprcursor_Theme"
        env = HYPRCURSOR_SIZE,32

        animations {
          enabled = 1
          bezier = default, 0.12, 0.92, 0.08, 1.0
          bezier = wind, 0.12, 0.92, 0.08, 1.0
          bezier = overshot, 0.18, 0.95, 0.22, 1.03
          bezier = liner, 1, 1, 1, 1

          animation = windows, 1, 5, wind, popin 60%
          animation = windowsIn, 1, 6, overshot, popin 60%
          animation = windowsOut, 1, 4, overshot, popin 60%
          animation = windowsMove, 1, 4, overshot, slide
          animation = layers, 1, 4, default, popin
          animation = fadeIn, 1, 7, default
          animation = fadeOut, 1, 7, default
          animation = fadeSwitch, 1, 7, default
          animation = fadeShadow, 1, 7, default
          animation = fadeDim, 1, 7, default
          animation = fadeLayers, 1, 7, default
          animation = workspaces, 1, 5, overshot, slidevert
          animation = border, 1, 1, liner
          animation = borderangle, 1, 24, liner, loop
        }

        env = QT_QPA_PLATFORMTHEME, qt6ct

        general {
          gaps_in = ${toString cfg.gapsIn}
          gaps_out = ${toString cfg.gapsOut}
          border_size = ${toString cfg.borderSize}
          col.active_border = rgba(ca9ee6ff) rgba(f2d5cfff) 45deg
          col.inactive_border = rgba(b4befecc) rgba(6c7086cc) 45deg
          layout = dwindle
          resize_on_border = true
        }

        group {
          col.border_active = rgba(ca9ee6ff) rgba(f2d5cfff) 45deg
          col.border_inactive = rgba(b4befecc) rgba(6c7086cc) 45deg
          col.border_locked_active = rgba(ca9ee6ff) rgba(f2d5cfff) 45deg
          col.border_locked_inactive = rgba(b4befecc) rgba(6c7086cc) 45deg
        }

        decoration {
          rounding = ${toString cfg.rounding}
          shadow:enabled = false

          blur {
            enabled = ${if cfg.enableBlur then "yes" else "no"}
            size = 6
            passes = 3
            new_optimizations = on
            ignore_opacity = on
            xray = false
          }
        }

        bind = , Print, exec, grim -g "$(slurp -w 0)" - | wl-copy
      '';
    };
  };
}
