{
  lib,
  runCommand,
}: let
  certificates = {
    anchor = [
      {
        name = "intra.net";
        path = ./certs/anchor/intra.net.pem;
      }
    ];
    server = [
      {
        name = "intra.net.internal";
        path = ./certs/server/intra.net.internal.pem;

        children = [
          {
            name = "directory.intra.net.internal";
            path = ./certs/server/intra.net.internal/directory.intra.net.internal.pem;
          }
          {
            name = "forge.dev.intra.net.internal";
            path = ./certs/server/intra.net.internal/forge.dev.intra.net.internal.pem;
          }
          {
            name = "pocket-id.intra.net.internal";
            path = ./certs/server/intra.net.internal/pocket-id.intra.net.internal.pem;
          }
        ];
      }
    ];
  };
in let
  mkInstallCertificates = dir: class: let
    mkInstallCertificate = dir: cert:
      ''
        mkdir -p ${dir}
        cp ${cert.path} ${dir}/${cert.name}.pem
      ''
      + lib.concatStrings (lib.mapAttrsToList
        (_: children: lib.concatMapStrings (mkInstallCertificate "${dir}/${cert.name}") children)
        (removeAttrs cert ["name" "path"]));
  in
    lib.concatStrings (lib.mapAttrsToList
      (class: certs: lib.concatMapStrings (mkInstallCertificate "${dir}/${class}") certs)
      class);
in
  runCommand "certs" {} (mkInstallCertificates "$out/etc/ssl" certificates)
