{ pkgs, ... }:
{
  home.packages = with pkgs; [
    boilr
  ];
}
