_: super: let
  inherit (super.attrsets) mapAttrsToList;
  inherit (super.lists) flatten optionals;
  inherit (super.strings) concatMapStringsSep escapeXML;
  inherit (super.types) mergeEqualOption mkOptionType;
in {
  generators =
    super.generators
    // {
      /**
      Translate a simple Nix expression to [Plist notation](https://en.wikipedia.org/wiki/Property_list).

      Binary data can be represented by wrapping a base64-encoded
      string with `mkPlistData`; `toPlist` emits these as `<data>`
      elements.

      Value
        : The value to be converted to Plist
      */
      toPlist = {escape ? true}: v: let
        expr = ind: x:
          if x == null
          then ""
          else if builtins.isBool x
          then bool ind x
          else if builtins.isInt x
          then int ind x
          else if builtins.isString x
          then str ind x
          else if builtins.isList x
          then list ind x
          else if x ? _type && x._type == "plistData"
          then data ind x.base64
          else if builtins.isAttrs x
          then attrs ind x
          else if builtins.isPath x
          then str ind (toString x)
          else if builtins.isFloat x
          then float ind x
          else abort "generators.toPlist: should never happen (v = ${v})";

        literal = ind: x: ind + x;

        bool = ind: x:
          literal ind (
            if x
            then "<true/>"
            else "<false/>"
          );
        maybeEscapeXML =
          if escape
          then escapeXML
          else x: x;
        int = ind: x: literal ind "<integer>${toString x}</integer>";
        str = ind: x: literal ind "<string>${maybeEscapeXML x}</string>";
        key = ind: x: literal ind "<key>${maybeEscapeXML x}</key>";
        float = ind: x: literal ind "<real>${toString x}</real>";
        data = ind: x: literal ind "<data>${x}</data>";

        indent = ind: expr "\t${ind}";

        item = ind: concatMapStringsSep "\n" (indent ind);

        list = ind: x:
          builtins.concatStringsSep "\n" [
            (literal ind "<array>")
            (item ind x)
            (literal ind "</array>")
          ];

        attrs = ind: x:
          builtins.concatStringsSep "\n" [
            (literal ind "<dict>")
            (attr ind x)
            (literal ind "</dict>")
          ];

        attr = let
          attrFilter = name: value: name != "_module" && value != null;
        in
          ind: x:
            builtins. concatStringsSep "\n" (
              flatten (
                mapAttrsToList (
                  name: value:
                    optionals (attrFilter name value) [
                      (key "\t${ind}" name)
                      (expr "\t${ind}" value)
                    ]
                )
                x
              )
            );
      in ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        ${expr "" v}
        </plist>'';

      /**
      Mark a string as base64-encoded binary data to be emitted inside a `<data>` tag by `toPlist`.

      # Inputs

      `base64`

      : 1\. Function argument

      # Type

      ```
      mkPlistData :: String -> { _type = "plistData"; base64 :: String; }
      ```
      */
      mkPlistData = base64: {
        _type = "plistData";
        inherit base64;
      };
    };

  types =
    super.types
    // {
      plistData = mkOptionType {
        name = "plistData";
        description = "plist <data> value";
        descriptionClass = "noun";
        check = x: x._type or null == "plistData" && builtins.isString (x.base64 or null);
        merge = mergeEqualOption;
      };
    };
}
