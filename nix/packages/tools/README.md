# Utilities

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
