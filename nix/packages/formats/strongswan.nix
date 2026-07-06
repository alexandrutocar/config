{
  lib,
  pkgs,
  ...
}:
# strongswan.conf / swanctl.conf configuration format.
#
# Mapping:
#   attrset          -> section          foo { ... }
#   bool             -> yes / no
#   int              -> decimal          (use a string for hex, e.g. "0x81010003")
#   float            -> decimal
#   string           -> verbatim value, quoted+escaped only when necessary
#   list             -> scalars joined with `listSeparator` (default ",")
#   null / [ ]       -> setting omitted entirely
#   ""               -> `key =` (explicitly clears an inherited value)
#
# Reserved keys inside a section:
#   _inherits = [ "conn-defaults" ... ]  -> `name : conn-defaults, ... {`
#                                           (section references, strongSwan >= 5.7.0)
#   _includes = [ "/run/secrets/*.conf" ] -> `include <path>` lines at this
#                                            section's level
#
# Attribute order is not preserved (Nix attrsets are sorted); where order
# is semantically relevant (auth rounds), set the `round` key explicitly.
{listSeparator ? ","}: let
  inherit
    (lib)
    any
    concatLists
    concatStringsSep
    hasInfix
    hasPrefix
    hasSuffix
    isAttrs
    isBool
    isFloat
    isInt
    isList
    isString
    mapAttrsToList
    optionalString
    replaceStrings
    types
    ;

  containsAny = chars: s: any (c: hasInfix c s) chars;

  # Characters forbidden in section names and keys per the strongswan.conf
  # grammar: . , : { } = " # \n \t space
  forbiddenKeyChars = ["." "," ":" "{" "}" "=" "\"" "#" "\n" "\t" "\r" " "];

  checkKey = key:
    if key == ""
    then throw "strongswan format: empty key names are not allowed"
    else if containsAny forbiddenKeyChars key
    then throw ''strongswan format: invalid key "${key}"; keys must not contain any of: . , : { } = " # or whitespace''
    else key;

  # Quote only when the raw value would be misparsed: `#` starts a comment,
  # `"` starts a quoted string, control characters break the line-based
  # grammar, and surrounding whitespace would be stripped.
  needsQuoting = s:
    containsAny ["\"" "#" "\n" "\t" "\r"] s
    || hasPrefix " " s
    || hasSuffix " " s;

  escapeQuoted =
    replaceStrings
    ["\\" "\"" "\n" "\t" "\r"]
    ["\\\\" "\\\"" "\\n" "\\t" "\\r"];

  renderScalar = v:
    if isBool v
    then
      (
        if v
        then "yes"
        else "no"
      )
    else if isInt v
    then toString v
    else if isFloat v
    then lib.strings.floatToString v
    else if isString v
    then
      (
        if needsQuoting v
        then "\"${escapeQuoted v}\""
        else v
      )
    else throw "strongswan format: unsupported value ${lib.generators.toPretty {} v}";

  renderValue = v:
    if isList v
    then concatStringsSep listSeparator (map renderScalar v)
    else renderScalar v;

  renderBody = indent: attrs: let
    includes = attrs._includes or [];
    settings = removeAttrs attrs ["_inherits" "_includes"];
  in
    map (p: "${indent}include ${toString p}") includes
    ++ concatLists (mapAttrsToList
      (name: value: let
        key = checkKey name;
      in
        if value == null || value == []
        then []
        else if isAttrs value
        then renderSection indent key value
        else ["${indent}${key} = ${renderValue value}"])
      settings);

  renderSection = indent: name: attrs: let
    refs = lib.toList (attrs._inherits or []);
    header =
      "${indent}${name}"
      + optionalString (refs != []) " : ${concatStringsSep ", " refs}"
      + " {";
  in
    [header] ++ renderBody "${indent}  " attrs ++ ["${indent}}"];

  renderConf = attrs: concatStringsSep "\n" (renderBody "" attrs) + "\n";

  valueType =
    types.nullOr
    (types.oneOf [
      types.bool
      types.int
      types.float
      types.str
      (types.listOf (types.oneOf [types.bool types.int types.float types.str]))
      (types.attrsOf valueType)
    ])
    // {
      description = "strongswan.conf value";
    };
in {
  type = types.attrsOf valueType;

  lib = {
    inherit renderConf;
    # format.lib.mkInherit [ "conn-defaults" ] { ... }
    mkInherit = refs: attrs: attrs // {_inherits = refs;};
  };

  generate = name: value: pkgs.writeText name (renderConf value);
}
