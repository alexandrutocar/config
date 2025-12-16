final: super: let
  /*
  * Lists all files (non-directories) in a given directory.
  *
  * Example:
  *   lib.filesystem.listFilesOnly ./configs
  *
  * Notes:
  * - Non-recursive: only lists files in the top-level of `dir`.
  * - Returns a flat list of file paths as strings.
  */
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

  #        super.mapAttrsToList (
  #         _name: _type: let
  #           _next = _directory + "/${_name}";
  #         in
  #           if _type == "directory"
  #           then _inner _next
  #           else (super.optional (filter _next _type) (mapper _next _type))
  #       ) (builtins.readDir _directory)

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
          then _inner next
          else super.optional (filter next type) (mapper next type);
      })
    );
  in
    _inner directory;
in {
  list = {
    shallow = directory:
      _list directory {
        filter = name: type: (super.strings.hasSuffix ".nix" name) && (type != "directory");
        mapper = name: type: (builtins.concatStringsSep "/" [directory name]);
      };
    recursive = directory:
      _list_recursive directory {
        filter = name: type: (super.strings.hasSuffix ".nix" name);
        mapper = name: type: name;
      };
  };

  map = {
    shallow = f: directory:
      _list directory {
        filter = name: type: (super.strings.hasSuffix ".nix" name) && (type != "directory");
        mapper = name: type: f (builtins.concatStringsSep "/" [directory name]);
      };

    recursive = f: directory:
      _list_recursive directory {
        filter = name: type: (super.strings.hasSuffix ".nix" name);
        mapper = name: type: f name;
      };
  };

  special = {
    patches = directory:
      builtins.listToAttrs (
        _list directory {
          filter = name: type: (type == "directory");
          mapper = name: type: {
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
          filter = name: type: (type == "directory");
          mapper = name: type: {
            inherit name;
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
}
