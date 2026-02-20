{ pkgs, inputs, ... }:
{
  # Noctalia shell
  environment.systemPackages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    ydotool
  ];

  environment.etc."glfw".source = "${pkgs.glfw}/lib";

  boot.kernelModules = [
    "uinput"
  ];
  users.groups.uinput = { };
  users.users.ashie.extraGroups = [ "uinput" ];

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="uinput", MODE="0660", OPTIONS+="static_node=uinput"
  '';
}
