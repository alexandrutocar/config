final: super: {
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
}
