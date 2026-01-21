{
  config,
  lib,
  pkgs,
  ...
}:
{
  users.groups.mlocate = { };
  services.locate = {
    enable = true;
    package = pkgs.mlocate;
    interval = "daily";
  };
}
