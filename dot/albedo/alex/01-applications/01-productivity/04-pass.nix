{pkgs, ...}: let
  pass = pkgs.pass.withExtensions (
    extensions: (
      with extensions; [
        pass-tomb
        pass-file
      ]
    )
  );
in {
  home.packages = [
    pass
  ];
}
