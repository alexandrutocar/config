final: super: {
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
  hex = super.types.strMatching "\#[0-9a-fA-F]{6}";
  bin = super.types.strMatching "0x[0-9a-fA-F]{6}";
}
