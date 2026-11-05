_: super: let
  inherit (super.types) mergeEqualOption mkOptionType;
in {
  plistData = mkOptionType {
    name = "plistData";
    description = "plist <data> value";
    descriptionClass = "noun";
    check = x: x._type or null == "plistData" && builtins.isString (x.base64 or null);
    merge = mergeEqualOption;
  };
}
