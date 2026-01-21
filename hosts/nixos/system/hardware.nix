{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Enable early KMS for the prompt
  boot.initrd.kernelModules = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "ashie" ];

  hardware.amdgpu.overdrive.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];
  services.lact.enable = true;

  services.fwupd.enable = true;

  services.usbguard = {
    enable = true;
    dbus.enable = true;
    implicitPolicyTarget = "block";
    # Restore keyboard/mouse if they disconnect/reconnect
    restoreControllerDeviceState = true;
    rules = ''
      allow id 1d6b:0002 serial "0000:02:00.0" name "xHCI Host Controller" hash "4+i1fOQzh6/CdbdfiwrmdTYf8TLnLkUDuN34mexLwrg=" parent-hash "/1e+oO/+QiBM87zSY7rDiPm4h+kOVFNNTkeJA9MoRos=" with-interface 09:00:00 with-connect-type ""
      allow id 1d6b:0003 serial "0000:02:00.0" name "xHCI Host Controller" hash "ViuugLRua/aPlAvgkXniQWreBpkM4XpeLtv3FPTwTSk=" parent-hash "/1e+oO/+QiBM87zSY7rDiPm4h+kOVFNNTkeJA9MoRos=" with-interface 09:00:00 with-connect-type ""
      allow id 1d6b:0002 serial "0000:0b:00.3" name "xHCI Host Controller" hash "TrEQZkga/umqtek+QDHj31Ymjb6xG1N177/tn/x3Wwo=" parent-hash "HYUOOWtH2SmhNDgrVquPq/YUStPUYo6SumTyP8wwEFk=" with-interface 09:00:00 with-connect-type ""
      allow id 1d6b:0003 serial "0000:0b:00.3" name "xHCI Host Controller" hash "ZqN/My4EyNiCWZdGdPH5rFMhfQthYbnRGW1/I0aO13s=" parent-hash "HYUOOWtH2SmhNDgrVquPq/YUStPUYo6SumTyP8wwEFk=" with-interface 09:00:00 with-connect-type ""
      allow id 1a40:0801 serial "" name "USB 2.0 Hub" hash "AGUYEKgZCSjWnBQRgECiKsBFduiNgQO6eIKZQaynmmY=" parent-hash "4+i1fOQzh6/CdbdfiwrmdTYf8TLnLkUDuN34mexLwrg=" via-port "1-2" with-interface 09:00:00 with-connect-type "hotplug"
      allow id 1532:0552 serial "1234" name "Razer Barracuda X 2.4" hash "iWNeDU4Lq0B+7fpGii17D5dD4RIgfQCZtC6/B72rD2o=" parent-hash "4+i1fOQzh6/CdbdfiwrmdTYf8TLnLkUDuN34mexLwrg=" with-interface { 01:01:00 01:02:00 01:02:00 01:02:00 01:02:00 03:01:00 } with-connect-type "hotplug"
      allow id 0781:55a3 serial "00015218091224140918" name " SanDisk 3.2Gen1" hash "DMEbNrSWf2Zj643VR0IoT+9AXBj1P+lXYZY6Tca93HE=" parent-hash "ViuugLRua/aPlAvgkXniQWreBpkM4XpeLtv3FPTwTSk=" with-interface { 08:06:50 08:06:62 } with-connect-type "hotplug"
      allow id 1532:0257 serial "00000000001A" name "Razer Huntsman Mini" hash "np7/cWye90u8Ym2VrOaMPtB7JbM0z5joqW4dzFWf6Mk=" parent-hash "TrEQZkga/umqtek+QDHj31Ymjb6xG1N177/tn/x3Wwo=" with-interface { 03:01:01 03:00:01 03:00:02 03:00:01 } with-connect-type "hotplug"
      allow id 1038:1852 serial "" name "SteelSeries Aerox 5 Wireless" hash "5YD8B0XxvySALtxGFAPYSjOuSgSHelgmtAYzPOVVzW0=" parent-hash "4+i1fOQzh6/CdbdfiwrmdTYf8TLnLkUDuN34mexLwrg=" via-port "1-10" with-interface { 03:01:02 03:00:00 03:00:00 03:00:00 03:00:00 } with-connect-type "hotplug"
      allow id 03f0:07b4 serial "1H544305B9" name "HyperX QuadCast 2" hash "zHNOiwP67DkizHez0CkaCcSjiKa/K/8zZHrAUSE4h3c=" parent-hash "AGUYEKgZCSjWnBQRgECiKsBFduiNgQO6eIKZQaynmmY=" with-interface { 01:01:00 01:02:00 01:02:00 01:02:00 01:02:00 01:02:00 01:02:00 01:02:00 03:00:00 } with-connect-type "unknown"
      allow id 03f0:09af serial "1H544305B9" name "HyperX QuadCast 2 Controller" hash "hHNUvgz8TH+wYR2h1fbF/JUIOCyZMgw+ylLErxsmNDg=" parent-hash "AGUYEKgZCSjWnBQRgECiKsBFduiNgQO6eIKZQaynmmY=" with-interface { 03:00:00 03:00:00 } with-connect-type "unknown"
      allow id 1532:00c1 serial "" name "Razer Viper V3 Pro" hash "B5HZa6gqaXvOnQI3eY7h8dorvfT91KEI6SqQ+Q+N0zU=" parent-hash "TrEQZkga/umqtek+QDHj31Ymjb6xG1N177/tn/x3Wwo=" via-port "3-4" with-interface { 03:01:02 03:01:00 03:01:01 } with-connect-type "hotplug"
    '';
  };

  services.xserver.xkb.layout = "de";
  services.xserver.xkb.options = "eurosign:e,caps:escape";

  console.keyMap = "de";

  environment.variables = {
    # Enforces RADV Vulkan implementation
    AMD_VULKAN_ICD = "RADV";
    # Increase AMD's shader cache size
    MESA_SHADER_CACHE_MAX_SIZE = "100G";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.comic-shanns-mono
  ];

  systemd.services.amdgpu-power-limit = {
    description = "Set AMDGPU Power Limit";
    wantedBy = [ "multi-user.target" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [
      "sysinit.target"
      "systemd-udev-settle.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "amdgpu-power-limit" ''
        set -euo pipefail
        shopt -s nullglob

        TARGET=374000000  # microWatts = 374W

        applied=0
        for hwmon in /sys/class/drm/card*/device/hwmon/hwmon*; do
          cap="$hwmon/power1_cap"
          minf="$hwmon/power1_cap_min"
          maxf="$hwmon/power1_cap_max"

          [[ -e "$cap" && -w "$cap" ]] || continue

          min=0; max=0
          [[ -r "$minf" ]] && min="$(cat "$minf")"
          [[ -r "$maxf" ]] && max="$(cat "$maxf")"

          val="$TARGET"
          if [[ "$min" -gt 0 && "$val" -lt "$min" ]]; then val="$min"; fi
          if [[ "$max" -gt 0 && "$val" -gt "$max" ]]; then val="$max"; fi

          echo "$val" > "$cap"
          echo "AMDGPU power cap set to $val µW (target $TARGET) for $hwmon (min=$min max=$max)"
          applied=1
        done

        if [[ "$applied" -eq 0 ]]; then
          echo "No writable AMDGPU power1_cap nodes found." >&2
          exit 1
        fi
      '';
    };
  };
}
