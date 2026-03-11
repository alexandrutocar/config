{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  nix-update-script,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "tlm";

  version = "1.2";

  src = fetchFromGitHub {
    owner = "yusufcanb";
    repo = "tlm";
    tag = finalAttrs.version;
    hash = "sha256-G6cpFzN7PuTve1RTZGp6VPnE93xVITEFVMCzrix6hXg=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  vendorHash = "sha256-JgmGPtPDMfRosa1I441pzAP0wBM36EaQarhhOOQ4+zw=";

  nativeBuildInputs = [
    pkg-config
  ];

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  passthru = {
    updateScript = nix-update-script {};
  };

  meta = {
    description = "Local CLI Copilot, powered by Ollama";
    homepage = "https://github.com/yusufcanb/tlm";
    changelog = "https://github.com/yusufcanb/tlm/releases/tag/${finalAttrs.version}";
    mainProgram = "tlm";
    longDescription = ''
      tlm is your CLI companion qwhich requires nothing except your workstation.
      It uses most efficient and powerful open-source models like Llama 3.3,
      Phi4, DeepSeek-R1, Qwen of your choice in your local environment
      to provide you the best possible command line assistance.
    '';
    license = lib.licenses.asl20;
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    maintainers = with lib.maintainers; [alexandrutocar];
  };
})
