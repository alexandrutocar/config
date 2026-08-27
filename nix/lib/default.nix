final: super: let
  # CERTIFICATES
  # ------------
  certificates = let
    inherit (super.strings) concatLines;
  in {
    mkCertificateChain = certs: concatLines certs;
  };

  # ATTRSETS
  # --------
  attrsets = {
    /*
    * Merges a list of attribute sets from left to right.
    *
    * Example:
    *   mergeAttrsList [
    *     { a = 1; b = 2; }
    *     { b = 3; c = 4; }
    *     { d = 5; }
    *   ] -> { a = 1; b = 3; c = 4; d = 5; }
    *
    * Implementation details:
    * - Uses builtins.foldl' for strict left-to-right evaluation.
    * - Merges each attribute set using the // operator.
    * - Later attribute sets override earlier ones for duplicate keys.
    *
    * Edge cases:
    * - Empty list returns an empty attribute set {}.
    * - Single element list returns that element unchanged.
    * - Nested attribute sets are not recursively merged; only merges top-level attributes.
    */
    mergeAttrsList = attrs: builtins.foldl' (acc: x: acc // x) {} attrs;
  };

  # OPTIONS
  # -------
  options = let
    inherit (super.attrsets) hasAttrByPath getAttrFromPath setAttrByPath;
    inherit (super.modules) mkIf mkMerge;
  in {
    mkScopedMerge = attrs: let
      pluckFunc = attr: values:
        mkMerge
        (map
          (v:
            mkIf
            (hasAttrByPath attr v)
            (getAttrFromPath attr v))
          values);

      pluckFuncs = attrs: values:
        mkMerge (map
          (attr: setAttrByPath attr (pluckFunc attr values))
          attrs);
    in
      pluckFuncs attrs;
  };

  # FACTER
  # ------
  facter = {
    report = {
      disk = let
        _find = let
          /*
          * Finds a disk in a facter report by its unix device name.
          *
          * Example:
          *   lib.report.disk.find.by-unix-name "/dev/sda" report -> { unix_device_names = [...]; resources = [...]; ... }
          *
          * Implementation details:
          * - Searches report.hardware.disk for a disk whose unix_device_names list contains the given name.
          * - Delegates to lists.findSingle to enforce exactly one match.
          *
          * Edge cases:
          * - Throws if no disk matches.
          * - Throws if more than one disk matches.
          */
          _by-unix-name = unix_device_name: report:
            super.lists.findSingle
            (disk: builtins.elem unix_device_name disk.unix_device_names)
            (throw "Could not find disk with specified unix device name.")
            (throw "Found multiple disks with the same specified unix device name.")
            report.hardware.disk;
        in {
          /*
          * Finds a disk in a facter report by its /dev/disk/by-id identifier.
          *
          * Example:
          *   lib.report.disk.find.by-id "ata-SAMSUNG_..." report -> { unix_device_names = [...]; resources = [...]; ... }
          *
          * Implementation details:
          * - Prepends "/dev/disk/by-id/" to the given id and delegates to by-unix-name.
          *
          * Edge cases:
          * - Throws if no disk matches.
          * - Throws if more than one disk matches.
          */
          by-id = id: report: _by-unix-name "/dev/disk/by-id/${id}" report;

          by-unix-name = _by-unix-name;
        };

        /*
        * Finds a resource of a given type within a disk's resource list.
        *
        * Example:
        *   lib.report.disk.resources.find.by-type "size" disk -> { type = "size"; value_1 = 512; value_2 = 1073741824; }
        *
        * Implementation details:
        * - Filters disk.resources for entries whose type field matches the given type.
        * - Delegates to lists.findSingle to enforce exactly one match.
        *
        * Edge cases:
        * - Throws if no resource of the given type is found.
        * - Throws if more than one resource of the given type is found.
        */
        _resources.find.by-type = type: disk:
          super.lists.findSingle
          (resource: resource.type == type)
          (throw "Did not find resource of type '${type}'.")
          (throw "Found multiple resources of type '${type}'.")
          disk.resources;
      in {
        /*
        * Returns the total size of a disk (in bytes) from a facter report, identified by its by-id name.
        *
        * Example:
        *   lib.report.disk.extra.size "ata-SAMSUNG_..." report -> 512110190592
        *
        * Implementation details:
        * - Locates the disk via find.by-id, then retrieves its "size" resource.
        * - Multiplies value_1 and value_2 from the size resource to produce the byte count.
        *
        * Edge cases:
        * - Throws if the disk or its size resource cannot be uniquely found.
        */
        extra.size = id: report: let
          size = _resources.find.by-type "size" (_find.by-id id report);
        in
          size.value_1 * size.value_2;

        find = _find;

        resources = _resources;
      };

      memory = {
        /*
        * Returns the total physical memory size (in bytes) across all memory modules in a facter report.
        *
        * Example:
        *   lib.report.memory.extra.size report -> 34359738368
        *
        * Implementation details:
        * - Iterates over report.hardware.memory (one entry per memory module).
        * - For each module, sums the range values of all resources with type "phys_mem".
        * - Accumulates across all modules with foldl'.
        *
        * Edge cases:
        * - Returns 0 if there are no memory modules or no "phys_mem" resources.
        * - Does not validate that ranges are non-overlapping.
        */
        extra.size = report:
          builtins.foldl'
          (total: memory:
            total
            + builtins.foldl'
            (range: resource: range + resource.range)
            0
            (builtins.filter (resource: resource.type == "phys_mem") memory.resources))
          0
          report.hardware.memory;
      };
    };
  };

  # CONVENTIONAL SECRETS
  # ------------ -------
  cs = {
    nspawn = {
      flags = {
        loadCredential = uuid: id: "--load-credential=${id}:/etc/credstore/${uuid}.${id}";
      };
    };
    systemd = {
      mkSetCredentialEncrypted = attrs:
        super.mapAttrsToList (name: payload: "${name}:${final.extra.strings.lines.asOne payload}") attrs;
    };
  };

  # TYPES
  # -----
  types = let
    inherit (super.types) strMatching;
  in {
    colors = {
      /**
      * Color type definitions for validating string formats.
      *
      * hex:
      *   - Matches web-style hex color strings.
      *   - Format: "#RRGGBB"
      *   - Example: "#ff00aa"
      *
      * bin:
      *   - Matches programming-style hex color strings with 0x prefix.
      *   - Format: "0xRRGGBB"
      *   - Example: "0xff00aa"
      *
      * Notes:
      *   - Both patterns only allow 6-digit hex colors.
      *   - Case-insensitive due to [0-9a-fA-F].
      */
      hex = strMatching "\#[0-9a-fA-F]{6}";
      bin = strMatching "0x[0-9a-fA-F]{6}";
    };
  };

  # MATH
  # ----
  math = let
    _mod = a: b: a - b * (a / b);

    _pow = base: exp:
      if exp == 0
      then 1
      else base * _pow base (exp - 1);

    /*
    * Internal recursive helper function to generate a numeric sequence.
    *
    * Usage:
    *   _seq [] 1 5 -> [1,2,3,4,5]
    *
    * Implementation:
    * - Appends the current `from` value to the accumulator array.
    * - Recursively increments `from` until it exceeds `to`.
    */
    _seq = _arr: from: to:
      if from > to
      then _arr
      else _seq (_arr ++ [from]) (from + 1) to;
  in {
    /*
    * Generates a numeric sequence from `from` to `to` inclusive.
    *
    * Example:
    *   lib.math.seq 3 7 -> [3,4,5,6,7]
    *
    * Notes:
    * - Returns an empty list if `from` > `to`.
    */
    seq = from: to: _seq [] from to;

    /*
    * Computes the power of a base raised to an exponent (base^exp).
    *
    * Example:
    *   lib.math.pow 2 3 -> 8
    *   lib.math.pow 5 0 -> 1
    *
    * Implementation:
    * - Uses recursion.
    * - Base case: any number to the power 0 is 1.
    */
    pow = _pow;

    /*
    * Computes the remainder of dividing a by b (a mod b).
    *
    * Example:
    *   lib.math.mod 7 3 -> 1
    *   lib.math.mod 10 5 -> 0
    *
    * Implementation:
    * - Uses integer division to compute the largest multiple of b not exceeding a.
    * - Subtracts that multiple from a to obtain the remainder.
    */
    mod = _mod;
  };

  # NETWORK
  # -------
  net = {
    mkHost' = domain: port: "${domain}@${toString port}";

    mkHost = domain: port: "${domain}:${toString port}";

    ipv6 = {
      enclose = address: "[" + address + "]";
    };

    ipv4 = {
      convert = {
        toInt = o0: o1: o2: o3: o0 * 16777216 + o1 * 65536 + o2 * 256 + o3;
        fromInt = number: "${toString (number / 16777216)}.${toString (math.mod (number / 65536) 256)}.${toString (math.mod (number / 256) 256)}.${toString (math.mod number 256)}";
      };
    };

    port = {
      prefix = {
        destination = {
          wan = port:
            if port < 10000 && port > 0
            then 10000 + port
            else throw "Ports destined to be forwarded externall must be in range between 0 and 9999 (inclusive).";
        };
      };
    };
  };

  # FILES
  # -----
  files = let
    _list = directory: {
      filter ? (_: _: true),
      mapper ? (name: _: name),
    }:
      super.flatten (
        super.mapAttrsToList (
          name: type: (
            super.optional (filter name type) (mapper name type)
          )
        ) (builtins.readDir directory)
      );

    _list_recursive = directory: {
      filter ? (_: _: true),
      mapper ? (name: _: name),
    }: let
      _inner = directory: (
        super.flatten (_list directory {
          mapper = name: type: let
            next = builtins.concatStringsSep "/" [directory name];
          in
            if type == "directory"
            then super.optionals (filter next type) (_inner next)
            else super.optional (filter next type) (mapper next type);
        })
      );
    in
      _inner directory;
  in {
    list = {
      /*
      * Lists all files (non-directories) in a given directory.
      *
      * Example:
      *   lib.extra.files.list.shallow ./configs
      *
      * Notes:
      * - Non-recursive: only lists files in the top-level of `dir`.
      * - Returns a flat list of file paths as strings.
      */
      shallow = directory:
        _list directory {
          filter = path: type: (type != "directory") && !(super.hasPrefix "_" (baseNameOf path)) && (super.strings.hasSuffix ".nix" path);
          mapper = name: _: (builtins.concatStringsSep "/" [directory name]);
        };

      recursive = directory:
        _list_recursive directory {
          filter = path: type:
            !(super.hasPrefix "_" (baseNameOf path))
            && (type == "directory" || super.strings.hasSuffix ".nix" path);
          mapper = name: _: name;
        };
    };

    map = {
      shallow = f: directory:
        _list directory {
          filter = path: type: (type != "directory") && !(super.hasPrefix "_" (baseNameOf path)) && (super.strings.hasSuffix ".nix" path);
          mapper = name: _: f (builtins.concatStringsSep "/" [directory name]);
        };

      recursive = f: directory:
        _list_recursive directory {
          filter = path: type:
            !(super.hasPrefix "_" (baseNameOf path))
            && (type == "directory" || super.strings.hasSuffix ".nix" path);
          mapper = name: _: f name;
        };
    };

    special = {
      patches = directory:
        builtins.listToAttrs (
          _list directory {
            filter = path: type: !(super.hasPrefix "_" (baseNameOf path)) && (type == "directory");
            mapper = name: _: {
              inherit name;
              value = import (builtins.concatStringsSep "/" [directory name "patch.nix"]);
            };
          }
        );

      /*
      * Lists all scripts in subdirectories as attribute sets.
      *
      * Example:
      *   lib.filesystem.listScripts pkgs ./scripts
      *
      * Implementation:
      * - Only considers directories.
      * - Uses `pkgs.callPackage` on `script.nix` inside each directory.
      * - Converts result to attribute sets keyed by directory name.
      */
      scripts = directory: pkgs:
        builtins.listToAttrs (
          _list directory {
            filter = path: type: !(super.hasPrefix "_" (baseNameOf path)) && (type == "directory");
            mapper = name: _: {
              name = builtins.substring 3 (builtins.stringLength name) name;
              value = pkgs.callPackage (builtins.concatStringsSep "/" [directory name "script.nix"]) pkgs;
            };
          }
        );

      /*
      * Lists all files and default.nix in subdirectories (shallow only).
      *
      * Example:
      *   lib.filesystem.listFilesShallow ./services
      *
      * Notes:
      * - Non-recursive beyond immediate subdirectories.
      * - For directories, automatically appends "/default.nix".
      * - Returns a flat list of paths as strings.
      */
      shallow = directory:
        _list directory {
          filter = _: _: true;
          mapper = name: type:
            builtins.concatStringsSep "/" [
              directory
              name
              (
                if type == "directory"
                then "script.nix"
                else "/"
              )
            ];
        };
    };
  };

  # COLORS
  # ------
  colors = {
    /*
    * Converts a hex color string to a binary-prefixed color string.
    *
    * Example:
    *   lib.colors.hexToBin "#FF00AA" -> "0xff00aa"
    *
    * Implementation details:
    * - Removes the leading '#' character.
    * - Converts all letters to lowercase.
    * - Prepends '0x' to produce a binary-style hex color string.
    *
    * Edge cases:
    * - Input must be in the format "#RRGGBB".
    * - Does not support shorthand "#RGB" notation.
    */
    hexToBin = input: "0x${super.strings.toLower (builtins.substring 1 (builtins.stringLength input - 1) input)}";

    /*
    * Converts a binary-prefixed color string to a hex color string.
    *
    * Example:
    *   lib.colors.binToHex "0xff00aa" -> "#ff00aa"
    *
    * Implementation details:
    * - Removes the leading '0x' prefix.
    * - Converts all letters to lowercase.
    * - Prepends '#' to produce a standard hex color string.
    *
    * Edge cases:
    * - Input must be in the format "0xRRGGBB".
    * - Does not validate length; assumes correct input.
    */
    binToHex = input: "#${super.strings.toLower (builtins.substring 2 (builtins.stringLength input - 1) input)}";

    /*
    * Converts a hex color string to a plain color string (without the leading '#').
    *
    * Example:
    *   lib.colors.hexToPlain "#FF00AA" -> "ff00aa"
    *
    * Implementation details:
    * - Removes the leading '#' character.
    * - Converts all letters to lowercase.
    * - Returns the color value without any prefix or delimiter.
    *
    * Edge cases:
    * - Input must be in the format "#RRGGBB".
    * - Does not support shorthand "#RGB" notation.
    */
    hexToPlain = input: "${super.strings.toLower (builtins.substring 1 (builtins.stringLength input - 1) input)}";

    /*
    * Converts a plain color string to a hex color string (with leading '#').
    *
    * Example:
    *   lib.colors.plainToHex "ff00aa" -> "#ff00aa"
    *
    * Implementation details:
    * - Converts all letters to lowercase.
    * - Prepends '#' to produce a standard hex color string.
    *
    * Edge cases:
    * - Input must be in the format "RRGGBB" without any prefix.
    * - Does not validate length; assumes correct input.
    */
    plainToHex = input: "#${super.strings.toLower input}";
  };

  # STRINGS
  # -------
  strings = {
    lines.asOne = lines: super.strings.concatStrings (super.strings.splitString "\n" lines);
  };
in {
  extra = {
    inherit attrsets certificates colors cs facter files math net options strings types;
  };

  inherit (import (./. + "/fixes?/toPlist.nix") final super) generators types;
}
