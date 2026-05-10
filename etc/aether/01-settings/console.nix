# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀█ █▄░█ █▀ █▀█ █░░ █▀▀
# █▄▄ █▄█ █░▀█ ▄█ █▄█ █▄▄ ██▄
#
# linux console, virtual console...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: let
  inherit (lib.lists) singleton;
in {
  imports = singleton (self + /etc/shared/01-settings/console.nix);

  # ────────────────────────────────────────────────────────────────────────
  # TODO: Modernize virtual console
  # - Find out a reason of why I would want that?
  # - Find out whether it is strictly necessary.
  # - Read more about virtual consoles
  #   - <https://wiki.archlinux.org/title/Linux_console>
  #   - <https://bylr.info/articles/2022/10/29/til-textual-fb-term/>
  # ────────────────────────────────────────────────────────────────────────
  # environment.systemPackages = with pkgs; [
  #   fbterm
  # ];
}
