# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀ █▀ █▀▀ █▄░█ ▀█▀ █ ▄▀█ █░░ █▀
# ██▄ ▄█ ▄█ ██▄ █░▀█ ░█░ █ █▀█ █▄▄ ▄█
#
# applications, fonts...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /dot/shared/settings/essentials.nix);

  home.packages = with pkgs; [
    # COMMUNICATION
    # -------------
    signal-desktop

    # LEARNING
    # --------
    anki

    # IMAGE
    # -----

    # Pictures
    gimp

    # Vector Graphics
    inkscape

    # AUDIO
    #------

    # Digital Audio Workstation

    # Recorder
    audacity

    # DOCUMENTS
    # ---------

    # Common
    libreoffice

    # READERS
    # -------
    sioyek

    # VIEWERS
    # -------

    # Pictures
    feh

    # Media
    mpv

    # Photography
    digikam

    # PLAYERS
    # -------
    mpv

    # Songs
    audacious
    cmus

    # INTERNET
    # --------
    # firefox
    # thunderbird

    # UTILITIES
    # ---------
    pass
  ];

  wayland.windowManager.river.settings = {
    rule-add."-app-id" = {
      # Anki
      "'anki'"."-title" = {
        "'Add'" = "float";
        "'Browse *'" = "float";
      };
    };
  };
}
