# Utilities

## `writeAuthZone`

This is a customized variation of `dns.util.writeZone`.

```nix
let
  inherit (lib.meta) getExe;
in {
  auth-zone = [
    (pkgs.custom.writeAuthZone "hosts.net.internal" {
      # Entries of a usual dns.nix zone file.
      SOA = {
        nameServer = "beidou.ns.hosts.net.internal.";
        minimum = 86400;
        serial = 2026082701;
        retry = 1800;
        expire = 604800;
        refresh = 3600;
        adminEmail = "noc@beidou.ns.hosts.net.internal";
      }
    });
  ]
}
```



## `writeShell`

This is a customized variation of `pkgs.writeShellApplication`.

```nix
let
  inherit (lib.meta) getExe;
in {
  ExecStart = getExe (
    pkgs.custom.writeShell {
      env = {
        # Expects "restic-password" credential to be set
        # and then assigns RESTIC_PASSWORD its value.
        SECRET.cred = "restic-password";

        # Does not read credential and sets SECRET_FILE to its path.
        SECRET_FILE = {
          cred = "restic-password";
          read = false;
        };

        # Sets value as it is specified (insecure).
        SECRET = "********************************"
      };

      text = ''
        echo "Hello 'writeShell'!"
      '';

      # `coreutils` are in default paths.
      # inputs = with pkgs; [coreutils];

      options = [
        "errexit"
      ];
    }
  )
}
```
