_: let 
  repository = rec {
    location = "/var/lib/git/" + name + ".git";
    name = "testing-declarative-repositories";
  };
in {
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
