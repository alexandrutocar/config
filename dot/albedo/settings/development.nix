# ────────────────────────────────────────────────────────────────────────
#
# █▀▄ █▀▀ █░█ █▀▀ █░░ █▀█ █▀█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
# █▄▀ ██▄ ▀▄▀ ██▄ █▄▄ █▄█ █▀▀ █░▀░█ ██▄ █░▀█ ░█░
#
# development, programming, writing, tools, extensions...
#
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: {
  # VISUAL STUDIO CODE
  # ------------------
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium.fhsWithPackages (pkgs:
      with pkgs; [
        openssl.dev
        rustup
        zlib
        pkg-config
      ]);
  };

  # SSH AGENT
  # ---------
  services.ssh-agent = {
    enable = true;
  };
}
