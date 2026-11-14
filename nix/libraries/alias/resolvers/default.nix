lib: let
  /*
  * Loads a directory of resolver files named `<provider>.<variant>.<v4|v6>.json`,
  * each a JSON list of addresses, into a nested attrset.
  *
  * Example:
  *   lib.extra.ip.address.importResolvers ./resolvers
  *   # => {
  *   #   cloudflare = {
  *   #     standard = { ipv4 = [ <addr> <addr> ]; ipv6 = [ <addr> <addr> ]; };
  *   #     block-malware = { ipv4 = [ ... ]; ipv6 = [ ... ]; };
  *   #     block-malware-and-adult-content = { ipv4 = [ ... ]; ipv6 = [ ... ]; };
  *   #   };
  *   # }
  */
  importResolvers = dir: let
    inherit
      (lib)
      filterAttrs
      hasSuffix
      removeSuffix
      splitString
      sublist
      concatStringsSep
      mapAttrsToList
      foldl'
      recursiveUpdate
      ;

    versions = {
      v4 = 4;
      v6 = 6;
    };

    files =
      filterAttrs
      (name: type: type == "regular" && hasSuffix ".json" name)
      (builtins.readDir dir);

    parse = name: let
      parts = splitString "." (removeSuffix ".json" name);
      n = builtins.length parts;
      tag = builtins.elemAt parts (n - 1);
    in
      if n < 3
      then throw "importResolvers: '${name}' does not match <provider>.<variant>.<v4|v6>.json"
      else if !(versions ? ${tag})
      then throw "importResolvers: '${name}' has unknown version '${tag}', expected v4 or v6"
      else {
        provider = builtins.head parts;
        # everything between provider and version, so dotted variants also work
        variant = concatStringsSep "." (sublist 1 (n - 2) parts);
        version = versions.${tag};
        path = dir + "/${name}";
      };

    toAttrs = name: _: let
      r = parse name;
    in {
      ${r.provider}.${r.variant}."ipv${toString r.version}" =
        lib.extra.ip.address.importJSON r.version r.path;
    };
  in
    foldl' recursiveUpdate {} (mapAttrsToList toAttrs files);
in
  importResolvers ./by-provider.variant
