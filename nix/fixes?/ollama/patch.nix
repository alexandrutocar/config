_: super: {
  ollama = super.ollama.overrideAttrs (old: let
    version = "0.17.7";
  in {
    inherit version;

    src = super.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v${version}";
      hash = "sha256-cAqc38NHvUo5gphq1csTyosTcpUjFcs0dzB0wreEGjs=";
    };
  });
}
