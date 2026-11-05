final: super: let
  inherit (builtins) attrNames concatMap listToAttrs match readDir;
in let
  libExtended = let
    byNamespace = concatMap (
      name: let
        matches = match "([^_].*)\\.nix" name;
      in
        if matches == null || name == "default.nix"
        then []
        else matches
    ) (attrNames (readDir ./nixos));
  in
    listToAttrs (map (namespace: {
        name = namespace;
        # lazy value: free to use super, final and extra
        value = super.${namespace} or {} // import ./nixos/${namespace}.nix final super;
      })
      byNamespace);
in
  assert !(libExtended ? extra) || throw "lib: ./nixos/extra.nix would shadow lib.extra";
    libExtended
    // {
      alias = import ./alias final;
      extra = import ./extra final super;
    }
