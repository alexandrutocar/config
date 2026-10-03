{
  pkgs,
  lib,
  ...
}: let
  inherit (lib.extra.net) mkHost';
  inherit (lib.modules) mkForce;
  inherit (lib.strings) concatMapStrings;
in {
  services = {
    nsd = {
      enable = true;

      settings = {
        server = {
          chroot = mkForce ''""'';

          interface = [
            (mkHost' "0.0.0.0" 53)
          ];

          server-count = 1;

          identity = "intra.net";
        };

        zone = [
          (let
            zonefile = pkgs.writeTextFile {
              name = "";
              text = let
                records = let
                  mkEntry = peer: ''
                    ${peer} IN AAAA ${mkIPv6Addr peer}
                  '';
                in
                  concatMapStrings mkEntry circle;
              in ''
                $ORIGIN ${domain}.
                $TTL 3600
                @ IN SOA ${mkHostFQDN anchor}. hostmaster.${domain}. (1 3600 900 604800 300)
                @ IN NS  ${mkHostFQDN anchor}.

                ${records}
              '';
            };
          in {
            name = ''"${domain}"'';
            zonefile = ''"${zonefile}"'';
          })
        ];
      };
    };
  };
}
