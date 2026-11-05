final: super: let
  adts = {
    ip = import ./adts/ip final super {scope = "lib.extra.ip";};
  };
in let
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
          *   lib.extra.facter.report.disk.find.by-unix-name "/dev/sda" report -> { unix_device_names = [...]; resources = [...]; ... }
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
          *   lib.extra.facter.report.disk.find.by-id "ata-SAMSUNG_..." report -> { unix_device_names = [...]; resources = [...]; ... }
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
        *   lib.extra.facter.report.disk.resources.find.by-type "size" disk -> { type = "size"; value_1 = 512; value_2 = 1073741824; }
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
        *   lib.extra.facter.report.disk.extra.size "ata-SAMSUNG_..." report -> 512110190592
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
        *   lib.extra.facter.report.memory.extra.size report -> 34359738368
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
      credentialsDirectory = unit: "/run/credentials/${unit}.service";
    };
  };

  # TYPES
  # -----
  types = let
    inherit (super.types) strMatching;
  in {
    ip = adts.ip.types;

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
    inherit (super.lists) elemAt genList;
  in let
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
    *   lib.extra.math.seq 3 7 -> [3,4,5,6,7]
    *
    * Notes:
    * - Returns an empty list if `from` > `to`.
    */
    seq = from: to: _seq [] from to;

    /*
    * Computes the power of a base raised to an exponent (base^exp).
    *
    * Example:
    *   lib.extra.math.pow 2 3 -> 8
    *   lib.extra.math.pow 5 0 -> 1
    *
    * Implementation:
    * - Uses recursion.
    * - Base case: any number to the power 0 is 1.
    */
    pow = _pow;

    /*
    * Returns 2^n for n in [0, 62].
    *
    * Example:
    *   pow2 0  -> 1
    *   pow2 10 -> 1024
    *   pow2 62 -> 4611686018427387904
    *
    * Implementation details:
    * - Backed by a precomputed table of 63 entries built with genList, where
    *   each entry is twice the previous one (entry 0 is 1).
    * - The table refers to itself, which works because Nix lists are lazy:
    *   an element is only evaluated when first demanded, and its value is then cached.
    * - The table is built once, when pow2 is defined, and shared by every call.
    *   A lookup is a plain elemAt, so there is no repeated multiplication.
    * - The range stops at 62 because 2^63 does not fit in a signed 64-bit
    *   integer (see maxInt).
    *
    * Edge cases:
    * - Throws if n < 0 or n > 62 (elemAt index out of bounds).
    * - Throws if n is not an integer.
    */
    pow2 = let
      table = genList (n:
        if n == 0
        then 1
        else 2 * elemAt table (n - 1))
      63;
    in
      n: elemAt table n;

    # Largest signed 64-bit integer (2^63 - 1), the maximum value a Nix integer can hold.
    maxInt = 9223372036854775807;

    /*
    * Computes the remainder of dividing a by b (a mod b).
    *
    * Example:
    *   lib.extra.math.mod 7 3 -> 1
    *   lib.extra.math.mod 10 5 -> 0
    *
    * Implementation:
    * - Uses integer division to compute the largest multiple of b not exceeding a.
    * - Subtracts that multiple from a to obtain the remainder.
    */
    mod = _mod;

    /*
    * Computes the floor of a divided by b (rounds towards negative infinity).
    *
    * Example:
    *   lib.extra.math.floorDiv 7 2 -> 3
    *   lib.extra.math.floorDiv (-7) 2 -> -4
    *
    * Implementation:
    * - Nix' `/` truncates towards zero.
    * - When the remainder is non-zero and its sign differs from b's, the
    *   truncated quotient is one too large, so it is decremented.
    */
    floorDiv = a: b: let
      q = a / b;
      r = a - q * b;
    in
      if r != 0 && (r < 0) != (b < 0)
      then q - 1
      else q;

    /*
    * Limits x to the inclusive interval [lo, hi].
    *
    * Example:
    *   lib.extra.math.clamp 0 8 12 -> 8
    *   lib.extra.math.clamp 0 8 (-3) -> 0
    *   lib.extra.math.clamp 0 8 5 -> 5
    *
    * Implementation:
    * - Returns lo below the interval, hi above it and x otherwise.
    */
    clamp = lo: hi: x:
      if x < lo
      then lo
      else if x > hi
      then hi
      else x;
  };

  # NETWORK
  # -------
  net = let
    inherit (super.strings) concatStrings concatStringsSep escapeURL hasInfix hasPrefix optionalString;
  in {
    interface = {
      /*
      * Builds an interface string of the form "host@port".
      *
      * Example:
      *   mkInterface "example.com" 8080 -> "example.com@8080"
      *   mkInterface "example.com" "80" -> "example.com@80"
      *   mkInterface "::1" 443          -> "::1@443"
      *
      * Implementation details:
      * - Joins host and the stringified port with "@" via concatStringsSep.
      * - port is rendered with toString, so integers and strings both work.
      * - Neither part is escaped or validated. Unlike mkAuthority, IPv6 hosts are
      *   not bracketed.
      *
      * Edge cases:
      * - A null port is not omitted: toString null is "", so the result is "host@".
      * - An empty host yields "@port".
      * - A host that itself contains "@" is passed through as is, so the result
      *   is ambiguous to parse back apart.
      */
      mkInterface = host: port: concatStringsSep "@" [host (toString port)];
    };

    url = {
      authority = {
        /*
        * Builds the authority component of a URL: [userinfo@]host[:port].
        *
        * Example:
        *   mkAuthority "example.com" 8080 "alice"                                  -> "alice@example.com:8080"
        *   mkAuthority "example.com" null { username = "alice"; password = "p@ss"; } -> "alice:p%40ss@example.com"
        *   mkAuthority "::1" 443 null                                              -> "[::1]:443"
        *   mkAuthority "example.com" null null                                     -> "example.com"
        *
        * Implementation details:
        * - user may be a string (shorthand for { username = "..."; }), an attrset
        *   with a username and an optional password, or null / {} for no userinfo.
        * - Username and password are percent-encoded with escapeURL. The host is not escaped.
        * - A password is only emitted when a username is also present.
        * - A host containing ":" that does not already start with "[" is treated as an
        *   IPv6 literal and wrapped in brackets.
        * - port is rendered with toString, so integers and strings both work.
        *   A null port is omitted.
        *
        * Edge cases:
        * - A user attrset without a username yields no userinfo, even if a password is set.
        * - An empty-string username is not treated as absent, so it yields a leading "@".
        *   Likewise, an empty password yields "user:@".
        * - An already-bracketed IPv6 host is passed through unchanged (no double brackets).
        * - Does not validate the host or port; malformed input is passed through as is.
        */
        mkAuthority = host: port: user: let
          userPart = let
            # Accept a plain string as shorthand for { name = "..."; }
            _parsed =
              if builtins.isString user
              then {username = user;}
              else user;

            hasUser = _parsed != null && _parsed != {} && (_parsed.username or null) != null;
            hasPass = hasUser && (_parsed.password or null) != null;
          in
            optionalString hasUser (
              escapeURL _parsed.username
              + optionalString hasPass ":${escapeURL _parsed.password}"
              + "@"
            );

          hostPart =
            if hasInfix ":" host && !(hasPrefix "[" host)
            then "[${host}]"
            else host;

          portPart = optionalString (port != null) ":${toString port}";
        in
          concatStrings [userPart hostPart portPart];
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
      *   lib.extra.files.special.scripts pkgs ./scripts
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
      *   lib.extra.files.special.shallow ./services
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
    *   lib.extra.colors.hexToBin "#FF00AA" -> "0xff00aa"
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
    *   lib.extra.colors.binToHex "0xff00aa" -> "#ff00aa"
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
    *   lib.extra.colors.hexToPlain "#FF00AA" -> "ff00aa"
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
    *   lib.extra.colors.plainToHex "ff00aa" -> "#ff00aa"
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
  inherit colors cs facter files math net strings types;

  ip = removeAttrs adts.ip ["types"];
}
