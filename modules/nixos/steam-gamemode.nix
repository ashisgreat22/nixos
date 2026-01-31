{
  pkgs,
  ...
}:
{
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  services.displayManager.sessionPackages = [
    (pkgs.writeTextFile {
      name = "steam-gamemode-session";
      destination = "/share/wayland-sessions/steam-gamemode.desktop";
      text = ''
        [Desktop Entry]
        Name=Steam GameMode
        Comment=Launch Steam in GameMode with Gamescope
        Exec=${pkgs.writeShellScript "steam-gamemode-start" ''
          # Load system environment
          . /etc/profile

          # Ensure we are in the user's home directory
          cd "$HOME" || exit 1

          exec >/tmp/steam-gamemode.log 2>&1
          echo "Starting Steam GameMode Session at $(date)"
          echo "User: $(whoami)"
          echo "PATH: $PATH"
          echo "Gamescope path: ${pkgs.gamescope}/bin/gamescope"

          # Check for steam binary
          if ! command -v steam >/dev/null; then
            echo "ERROR: steam command not found in PATH"
            exit 1
          fi

          echo "Launching gamescope..."
          exec ${pkgs.gamescope}/bin/gamescope -f -e -- steam -gamepadui
        ''}
        Type=Application
      '';
      derivationArgs = {
        passthru = {
          providedSessions = [ "steam-gamemode" ];
        };
      };
    })
  ];
}
