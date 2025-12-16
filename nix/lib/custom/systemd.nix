final: super: {
  mkSetCredentialEncrypted = attrs:
    super.mapAttrsToList (name: payload: "${name}:${final.custom.strings.lines.asOne payload}") attrs;

  mkEnvironment = attrs:
    super.mapAttrsToList (name: value: super.toShellVar name value) attrs;
}
