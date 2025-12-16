# Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ────────────────────────────────────────────────────────────────────────
# WIP: This package has a pull-request in nixos/nixpkgs.
# ────────────────────────────────────────────────────────────────────────
{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  alsa-lib,
  makeDesktopItem,
  copyDesktopItems,
  nix-update-script,
  ...
}:
buildGoModule (finalAttrs: {
  pname = "sonicradio";

  version = "0.8.11";

  src = fetchFromGitHub {
    owner = "dancnb";
    repo = "sonicradio";
    tag = "v${finalAttrs.version}";
    hash = "sha256-2p/QgE6nCHvkpUwNCCH6PWrR35vkJKdtxlmpQALhgPI=";
  };

  strictDeps = true;

  vendorHash = "sha256-iaRs3YESYRu4BQhnPJQXAU1xw1lEpY5Kf2U9KRIodNw=";

  nativeBuildInputs = [
    copyDesktopItems
    pkg-config
  ];

  buildInputs = [
    alsa-lib
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "SonicRadio";
      exec = "sonicradio";
      terminal = true;
      comment = finalAttrs.meta.description;
      desktopName = "Sonic Radio";
      genericName = "Terminal Radio Player";
      categories = [
        "AudioVideo"
        "Audio"
        "ConsoleOnly"
      ];
      keywords = [
        "Radio"
        "TUI"
        "Internet"
        "Streaming"
      ];
    })
  ];

  # ────────────────────────────────────────────────────────────────────────
  # TODO: Requires networking.
  # ────────────────────────────────────────────────────────────────────────
  doCheck = false;

  passthru = {
    updateScript = nix-update-script {};
  };

  meta = {
    description = "TUI radio player making use of Radio Browser API and Bubbletea";
    homepage = "https://github.com/dancnb/sonicradio";
    changelog = "https://github.com/dancnb/sonicradio/releases/tag/v${finalAttrs.version}";
    mainProgram = "sonicradio";
    longDescription = ''
      A stylish TUI radio player making use of Radio Browser API and Bubbletea.
      Sonicplayer requires mpv, ffplay (ffmpeg), vlc, mplayer or mpd installed.
    '';
    license = lib.licenses.mit;
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    maintainers = with lib.maintainers; [alexandrutocar];
  };
})
