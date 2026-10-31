# spell-checker: ignore aikgen
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
# NOTE: This module keeps the general structure of the upstream one but
#       applies a few adjustments tailored to my setup. Only the pieces
#       I actually use are kept; unused options have been trimmed. Some
#       defaults have been changed/removed to reduce noise and clutter.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.strongswan;
  format = pkgs.formats.strongswan {};
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/networking/strongswan-swanctl/module.nix"
    "services/networking/strongswan.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkPackageOption;
  in {
    services.strongswan = {
      enable = mkEnableOption "strongSwan";

      package = mkPackageOption pkgs "strongswan" {};

      settings = {
        strongswan = lib.mkOption {
          type = format.type;
          default = {};
          description = ''
            strongswan.conf contents as attributes. See
            {manpage}`strongswan.conf(5)` for available keys. Use the reserved
            `_inherits` key for section references and `_includes` for
            include statements (e.g. secrets outside the Nix store).
          '';
        };
        swanctl = lib.mkOption {
          type = format.type;
          default = {};
          description = ''
            swanctl.conf contents as attributes. See
            {manpage}`swanctl.conf(5)` for available keys. Use the reserved
            `_inherits` key for section references and `_includes` for
            include statements (e.g. secrets outside the Nix store).
          '';
        };
      };
    };
  };

  config = let
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.lists) optional;
  in
    mkIf cfg.enable (mkMerge [
      {
        environment.etc."swanctl/swanctl.conf".source = format.generate "swanctl.conf" cfg.settings.swanctl;
        environment.etc."strongswan.conf".source = format.generate "strongswan.ctl" cfg.settings.strongswan;
      }
      {
        systemd.services.strongswan = {
          description = "strongSwan IPsec IKEv1/IKEv2 Daemon";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          path = with pkgs; [
            kmod
            iproute2
            iptables
            util-linux
          ];
          restartTriggers =
            [
              config.environment.etc."swanctl/swanctl.conf".source
              config.environment.etc."strongswan.conf".source
            ]
            ++ optional (cfg.settings.swanctl ? _includes) cfg.settings.swanctl._includes
            ++ optional (cfg.settings.strongswan ? _includes) cfg.settings.strongswan._includes;
          serviceConfig = {
            ExecStart = "${cfg.package}/sbin/charon-systemd";
            Type = "notify";
            ExecStartPost = "${cfg.package}/sbin/swanctl --load-all --noprompt";
            ExecReload = "${cfg.package}/sbin/swanctl --reload";
            Restart = "on-abnormal";
          };
        };
      }
      {
        # The swanctl command complains when the following directories don't exist:
        # See: https://wiki.strongswan.org/projects/strongswan/wiki/Swanctldirectory
        systemd.tmpfiles.rules = [
          # Trusted X.509 End Entity Certificates
          "d /etc/swanctl/x509 -"
          # Trusted X.509 Certificate Authority Certificates
          "d /etc/swanctl/x509ca -"
          "d /etc/swanctl/x509ocsp -"
          # Trusted X.509 Attribute Authority Certificates
          "d /etc/swanctl/x509aa -"
          # Attribute Certificates
          "d /etc/swanctl/x509ac -"
          # Certificate Revocation Lists
          "d /etc/swanctl/x509crl -"
          # Raw Public Keys
          "d /etc/swanctl/pubkey -"
          # Private Keys
          "d /etc/swanctl/private -"
          # RSA Private Keys (PKCS#1)
          "d /etc/swanctl/rsa -"
          # ECDSA Private Keys
          "d /etc/swanctl/ecdsa -"
          "d /etc/swanctl/bliss -"
          # Private Keys (PKCS#8)
          "d /etc/swanctl/pkcs8 -"
          # Containers (PKCS#12)
          "d /etc/swanctl/pkcs12 -"
        ];
      }
    ]);
}
