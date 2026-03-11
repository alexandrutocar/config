_: super: {
  git = super.git.overrideAttrs (old: {
    # https://github.com/NixOS/nixpkgs/issues/379657
    doInstallCheck = false;
  });

  # gitMinimal = super.gitMinimal.overrideAttrs (old: {
  #   # https://github.com/NixOS/nixpkgs/issues/379657
  #   doInstallCheck = false;
  # });
}
