final: super: {
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
}
