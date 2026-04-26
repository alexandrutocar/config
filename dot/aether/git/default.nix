# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▀ ▀█▀ █░█ █▀▀ █▀█ ░░▄▀ █▀▀ █ ▀█▀
# █▀█ ██▄ ░█░ █▀█ ██▄ █▀▄ ▄▀░░ █▄█ █ ░█░
#
# git@aether
#
# ────────────────────────────────────────────────────────────────────────
{lib, ...}: let
  inherit (lib.extra.files.list) recursive;

  repository = rec {
    location = "/var/lib/git/" + name + ".git";
    name = "testing-declarative-repositories";
  };
in {
  imports = recursive ./repositories;

  home = {
    homeDirectory = "/var/lib/git";
    stateVersion = "25.11";
    username = "git";
  };

  programs.git = {
    enable = true;
  };

  # systemd.user.tmpfiles.rules = [
  #   "d ${repository.location} 0755 git git -"
  # ];

  # home.activation.declarative-git-repositories = lib.hm.dag.entryAfter ''
  #   if [ ! -d ${repository.location}/HEAD ]; then
  #     git init --bare ${repository.location}
  #   fi
  # '';
}
