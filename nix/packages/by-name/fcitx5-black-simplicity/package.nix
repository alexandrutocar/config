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
  stdenvNoCC,
  fetchFromGitHub,
  unstableGitUpdater,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fcitx5-black-simplicity";
  version = "0-unstable-2021-11-23";

  src = fetchFromGitHub {
    owner = "fuzakebito";
    repo = finalAttrs.pname;
    rev = "27e279c4e4f1c2318b19360367a0b9a5ef83efbb";
    hash = "sha256-XWnYaUBwXDJwy4n37WKW3DEKkUdUEOFvR/8v5ibF96k=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  installPhase = ''
    runHook preInstall

    mkdir -pv $out/share/fcitx5/themes/
    cp -rv ./Black-Simplicity/ $out/share/fcitx5/themes/

    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater {};

  meta = with lib; {
    description = "Monochrome skin that gives a simpler look to fcitx5";
    homepage = "https://github.com/fuzakebito/fcitx5-Black-Simplicity";
    license = licenses.unfree;
    maintainers = with maintainers; [alexandrutocar];
    platforms = platforms.all;
  };
})
