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
# NOTE: This is a simplified rewrite of the upstream package. In
#       contrast to upstream it does not rename environment file.
# ────────────────────────────────────────────────────────────────────────
{
  lib,
  fetchFromGitHub,
  php,
  ...
}:
php.buildComposerProject2 (finalAttrs: {
  pname = "davis";
  version = "5.3.0";

  src = fetchFromGitHub {
    owner = "tchapi";
    repo = "davis";
    tag = "v${finalAttrs.version}";
    hash = "sha256-YLVfcoC8cIcCfi7R2zWXNxD4P+KIXOCL+MqFEt2Z7Tc=";
  };

  strictDeps = true;

  vendorHash = "sha256-ub2iv4455AAP9ohN2Zh+8DCbYT1uJOasMeZ/P7tDdw0=";

  composerNoPlugins = false;

  postInstall = ''
    chmod -R u+w $out/share

    # Only include the files needed for runtime in the derivation
    mv $out/share/php/davis/{bin,config,migrations,public,src,templates,tests,translations,vendor,.env,composer.json,composer.lock,symfony.lock} $out

    rm -rf "$out/share"
  '';

  meta = with lib; {
    changelog = "https://github.com/tchapi/davis/releases/tag/v${finalAttrs.version}";
    description = "Simple CardDav and CalDav server inspired by Baïkal";
    homepage = "https://github.com/tchapi/davis";
    license = licenses.mit;
    maintainers = with maintainers; [ramblurr];
  };
})
