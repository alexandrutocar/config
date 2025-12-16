final: super: let
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
}
