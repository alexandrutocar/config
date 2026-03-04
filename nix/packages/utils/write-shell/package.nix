{
  writeTextFile,
  runtimeShell,
  shellcheck,
  stdenv,
  lib,
  gnused,
  coreutils,
  util-linux,
  ...
}: name: {
  /*
  {
    # expects "restic-password" credential to be set
    # and then assigns RESTIC_PASSWORD its value.
    SECRET.cred = "restic-password";

    # does not read credential and sets SECRET_FILE to its path.
    SECRET_FILE = {
      cred = "restic-password";
      read = false;
    };

    # sets value as it is specified (insecure)
    SECRET = "********************************"
  }

  Type: AttrSet
  */
  env ? {},
  /**
  Script content.

  Type: Lines
  */
  text,
  paths ? ([coreutils gnused util-linux] ++ inputs),
  /**
  Available binaries.

  Type: List of Packages
  */
  inputs ? [],
  /**
  Type: List of Strings
  */
  options ? [
    # "errexit"
    "nounset"
    "pipefail"
  ],
}: let
  inherit (lib.strings) concatMapAttrsStringSep concatMapStringsSep isStringLike makeBinPath optionalString toShellVar;
  inherit (lib.meta) getExe;
in
  writeTextFile {
    destination = "/bin/${name}";
    executable = true;

    inherit name;

    text = ''
      #!${runtimeShell}
      ${concatMapStringsSep "\n" (option: "set -o ${option}") options}

      # (0.1) Environment Path (Inputs)
      export PATH="${makeBinPath paths}:$PATH"

      # (0.2) External Libraries
      ${builtins.readFile ./lib/logs.sh}
      ${builtins.readFile ./lib/cred.sh}

      # (0.3) Environment Variables (Credentials)
      ${optionalString (env != null) (
        env
        |> concatMapAttrsStringSep "" (
          name: from:
            if isStringLike from
            then
              # Simple Assignment
              ''
                ${toShellVar name from}
                # shellcheck disable=SC2034
                export "${name}"
              ''
            else let
              type =
                if (from.read or true)
                then "read"
                else "type";
            in ''
              cred ${type} ${name} ${from.cred}
            ''
        )
      )}

      # ##################################################
      # ##################################################
      # ##################################################
      ${text}
    '';

    checkPhase = ''
      runHook preCheck
      ${stdenv.shellDryRun} "$target"
      ${optionalString shellcheck.compiler.bootstrapAvailable ''
        ${getExe shellcheck} "$target"
      ''}
      runHook postCheck
    '';

    allowSubstitutes = true;
    preferLocalBuild = false;
  }
