_: super: {
  creek = super.creek.overrideAttrs (old: let
    version = "0.4.5-20260728";
    deps = super.callPackage ./build.zig.zon.nix {};
  in {
    inherit deps;

    src = super.fetchFromGitHub {
      owner = "alexandrutocar";
      repo = "creek";
      tag = "v${version}";
      hash = "sha256-syutpCRjy0G8Gl+jiJHd7HKsmLUm3NtajX/xm7n9eZs=";
    };

    nativeBuildInputs = with super; [
      zig_0_16
      pkg-config
      wayland-scanner
    ];

    zigBuildFlags = [
      "--system"
      "${deps}"
    ];
  });
}
