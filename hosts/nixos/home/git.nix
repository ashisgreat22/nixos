{ ... }:
{
  programs.git = {
    enable = true;
    settings.user.name = "ashisgreat22";
    settings.user.email = "dev@ashisgreat.xyz";
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };
}
