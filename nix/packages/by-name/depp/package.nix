{
  lib,
  fetchFromGitHub,
  buildGoModule,
  pkg-config,
  nix-update-script,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "depp";

  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "nmeum";
    repo = "depp";
    tag = finalAttrs.version;
    hash = "sha256-QI0qRpkM2tmYG5h6Wg0WJcmaps5kQ3lnIioNekG9ObY=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  vendorHash = "sha256-6DyeOj/qr6AaxGBJYzDP1H5pZLMiZ7nHrZvxh7Z+khs=";

  nativeBuildInputs = [
    pkg-config
  ];

  passthru = {
    updateScript = nix-update-script {};
  };

  meta = let
    inherit (lib.lists) flatten;
  in {
    description = "No frills static page generator for Git repositories ";
    homepage = "https://github.com/nmeum/depp";
    changelog = "https://github.com/nmeum/depp/releases/tag/${finalAttrs.version}";
    mainProgram = "depp";
    license = lib.licenses.gpl3;
    platforms = flatten (with lib.platforms; [darwin linux windows]);
    maintainers = with lib.maintainers; [alexandrutocar];
  };
})
