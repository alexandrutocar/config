/*
* IP addresses and networks as one algebraic data type.
*
*   Ip = Address { version, words, prefixLength }  with host bits allowed
*      | Network { version, words, prefixLength }  host bits must be zero
*
* - Data is minimal and function-free: plain attrsets tagged with `_type`.
* - Constructors take the IP version. Utility functions read version and
*   dispatch to that version's family.
*
* Naming:
*   from*  build data          to*   render text or a number
*   get*   extract a part      with* copy with one field replaced
*   is*    predicates          plain verbs: operations (next, contains, subnets, ...)
*/
final: super: {scope}: let
  inherit (super.attrsets) attrNames;
  inherit (final.extra.math) clamp floorDiv maxInt pow2;
  inherit (super.lists) all any compareLists concatLists drop elemAt filter foldl' genList head imap0 isList length reverseList sort tail take;
  inherit (super.strings) concatMapStringsSep concatStringsSep fixedWidthString fromJSON hasInfix hasPrefix isString match splitString toLower;
  inherit (super.trivial) bitAnd compare deepSeq fromHexString importJSON isInt mod toHexString;
  inherit (super.types) isType setType;

  _show = super.generators.toPretty {};

  # TEXT
  # ----

  # Strict decimal: 1 to 5 digits, no leading zeros (avoids octal ambiguity), bounded by max.
  _parseDecimal = max: v:
    if !(isString v) || match "[0-9]{1,5}" v == null
    then throw "'${toString v}' is not a decimal number"
    else if v != "0" && hasPrefix "0" v
    then throw "'${v}' has leading zeros"
    else let
      n = fromJSON v;
    in
      if n > max
      then throw "${v} exceeds maximum ${toString max}"
      else n;

  # Dotted quad -> 4 octets. Shared by IPv4 and IPv6 (embedded IPv4 suffix).
  _parseOctets = v: let
    m =
      if isString v
      then match "([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.([0-9]+)" v
      else null;
  in
    if m == null
    then throw "${_show v} is not a dotted-quad IPv4 address"
    else map (_parseDecimal 255) m;

  # Full IPv6 address: 8 hextets, at most one "::", optional dotted-quad suffix.
  _parseHextets = v: let
    fail = msg: throw "${msg} (got ${_show v})";

    parseHextet = g:
      if match "[0-9a-fA-F]{1,4}" g == null
      then fail "invalid hextet '${g}'"
      else fromHexString g;

    # allowOctets: an embedded dotted quad is accepted as the very last group.
    parseSide = allowOctets: part:
      if part == ""
      then []
      else let
        groups = splitString ":" part;
        lastIndex = length groups - 1;
      in
        concatLists (imap0
          (i: g:
            if !(hasInfix "." g)
            then [(parseHextet g)]
            else if allowOctets && i == lastIndex
            then let
              o = _parseOctets g;
            in [(elemAt o 0 * 256 + elemAt o 1) (elemAt o 2 * 256 + elemAt o 3)]
            else fail "embedded IPv4 is only allowed as the final 32 bits")
          groups);

    parts = splitString "::" v;
  in
    if !(isString v) || v == ""
    then throw "expected a non-empty string, got ${_show v}"
    else if match "[0-9a-fA-F:.]+" v == null
    then fail "contains characters that are not part of a bare address (zone id, prefix length, brackets, whitespace)"
    else if length parts == 1
    then let
      ws = parseSide true v;
    in
      if length ws != 8
      then fail "expected 8 groups without '::', found ${toString (length ws)}"
      else ws
    else if length parts == 2
    then let
      left = parseSide false (elemAt parts 0);
      right = parseSide true (elemAt parts 1);
      missing = 8 - length left - length right;
    in
      if missing < 1
      then fail "'::' must stand for at least one group of zeros"
      else left ++ genList (_: 0) missing ++ right
    else fail "more than one '::'";

  _hextet = n: toLower (toHexString n);

  # Canonical IPv6 text per RFC 5952 (lowercase, longest zero run >= 2 compressed, first wins).
  _formatHextets = ws: let
    scan =
      foldl'
      (st: i:
        if elemAt ws i != 0
        then st // {curLen = 0;}
        else let
          start =
            if st.curLen == 0
            then i
            else st.curStart;
          len = st.curLen + 1;
        in
          st
          // {
            curStart = start;
            curLen = len;
          }
          // (
            if len > st.bestLen
            then {
              bestStart = start;
              bestLen = len;
            }
            else {}
          ))
      {
        curStart = 0;
        curLen = 0;
        bestStart = 0;
        bestLen = 0;
      }
      (genList (i: i) 8);
    join = concatMapStringsSep ":" _hextet;
  in
    if scan.bestLen < 2
    then join ws
    else join (take scan.bestStart ws) + "::" + join (drop (scan.bestStart + scan.bestLen) ws);

  # WORDS
  # -----

  # Operations on fixed-width, big-endian word vectors (most significant word first).
  _mkWords = {
    wordBits,
    wordCount,
  }: let
    totalBits = wordBits * wordCount;
    base = pow2 wordBits;

    # hostMasks[len][i]: mask of the host bits of word i for a /len. Built lazily, once per len.
    hostMasks =
      genList
      (len: genList (i: pow2 (wordBits - clamp 0 wordBits (len - wordBits * i)) - 1) wordCount)
      (totalBits + 1);
    hostMask = len: elemAt hostMasks len;

    zipWith = f: a: b: genList (i: f (elemAt a i) (elemAt b i)) wordCount;
  in {
    inherit base hostMask totalBits;
    bits = wordBits;
    count = wordCount;
    max = base - 1;

    isValid = ws: isList ws && length ws == wordCount && all (x: isInt x && x >= 0 && x < base) ws;
    isValidPrefixLength = len: isInt len && len >= 0 && len <= totalBits;

    # Clear / keep / set / test the host bits of a /len.
    network = ws: len: zipWith (x: m: x - bitAnd x m) ws (hostMask len);
    host = ws: len: zipWith bitAnd ws (hostMask len);
    last = ws: len: zipWith (x: m: x - bitAnd x m + m) ws (hostMask len);
    hasHostBits = ws: len: any (x: x != 0) (zipWith bitAnd ws (hostMask len));

    # Adds a signed n at word index i, carrying/borrowing towards word 0.
    offsetAt = ws: i: n: let
      go = idx: carry:
        if carry == 0
        then take (idx + 1) ws
        else if idx < 0
        then
          throw (
            if carry > 0
            then "result exceeds the ${toString totalBits}-bit address space"
            else "result is below zero"
          )
        else let
          s = elemAt ws idx + carry;
          q = floorDiv s base;
        in
          go (idx - 1) q ++ [(s - q * base)];
    in
      go i n ++ drop (i + 1) ws;

    # Word index `i` and value `unit` of the least significant network bit of a /len (len >= 1).
    unitAt = len: let
      i = (len - 1) / wordBits;
    in {
      inherit i;
      unit = pow2 (wordBits * (i + 1) - len);
    };
  };

  # FAMILIES
  # --------
  #
  # Everything that differs between IP versions. Functions look the family up
  # from the data's `version` field.

  _families = {
    "4" = {
      version = 4;
      words = _mkWords {
        wordBits = 8;
        wordCount = 4;
      };
      parse = _parseOctets;
      format = concatMapStringsSep "." toString;
      # IPv4 has no abbreviated prefix syntax.
      expandPrefix = v: v;
      group = {
        separator = ".";
        text = toString;
        full = toString;
      };
    };

    "6" = {
      version = 6;
      words = _mkWords {
        wordBits = 16;
        wordCount = 8;
      };
      parse = _parseHextets;
      format = _formatHextets;
      # "fd00:1:2:3" (no '::', fewer than 8 groups) means "fd00:1:2:3::".
      expandPrefix = v:
        if match "[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){0,6}" v != null
        then "${v}::"
        else v;
      group = {
        separator = ":";
        text = _hextet;
        full = n: fixedWidthString 4 "0" (_hextet n);
      };
    };
  };

  _versions = map (k: _families.${k}.version) (attrNames _families);

  _isVersion = v: isInt v && _families ? ${toString v};

  _family = version:
    if _isVersion version
    then _families.${toString version}
    else throw "unsupported IP version ${_show version}; expected one of ${concatMapStringsSep ", " toString _versions}";

  # DATA
  # ----

  _tags = {
    address = "ip-address";
    network = "ip-network";
  };

  # Raw constructors: no validation; the from* functions below validate.
  Address = version: ws: prefixLength:
    setType _tags.address {
      inherit prefixLength version;
      words = ws;
    };
  Network = version: ws: prefixLength:
    setType _tags.network {
      inherit prefixLength version;
      words = ws;
    };

  # Shape checks: closed record, valid version, words and prefix length.
  _isPrefixed = tag: allowHostBits: v:
    isType tag v
    && attrNames v == ["_type" "prefixLength" "version" "words"]
    && _isVersion v.version
    && (let
      w = (_family v.version).words;
    in
      w.isValid v.words
      && w.isValidPrefixLength v.prefixLength
      && (allowHostBits || !(w.hasHostBits v.words v.prefixLength)));

  _isAddress = _isPrefixed _tags.address true;
  _isNetwork = _isPrefixed _tags.network false;
  _isIP = v: _isAddress v || _isNetwork v;

  # Exhaustive elimination over the two constructors.
  _caseOf = {
    address,
    network,
  }: v:
    if _isAddress v
    then address v
    else if _isNetwork v
    then network v
    else throw "expected IP address or network data, got ${_show v}";

  # HELPERS
  # -------

  _strict = v: deepSeq v v;
  _succeeds = v: (builtins.tryEval (deepSeq v true)).success;

  # Adds "while evaluating <scope>.<path>" to errors and forces the result,
  # so errors surface inside that context.
  _guard = path: v:
    builtins.addErrorContext
    "while evaluating ${scope}.${concatStringsSep "." path}"
    (_strict v);

  _expect = what: pred: v:
    if pred v
    then v
    else throw "expected ${what}, got ${_show v}";
  _expectAddress = _expect "IP address data" _isAddress;
  _expectNetwork = _expect "IP network data" _isNetwork;
  _expectIP = _expect "IP address or network data" _isIP;

  _expectVersion = version: v:
    if v.version == version
    then v
    else throw "expected IPv${toString version} data, got IPv${toString v.version} data";

  _wordsOf = v: (_family v.version).words;

  _expectPrefixLength = version: len: let
    w = (_family version).words;
  in
    if w.isValidPrefixLength len
    then len
    else throw "prefixLength must be an integer between 0 and ${toString w.totalBits}, got ${_show len}";

  # Words of an address given as a plain string (no "/len") or as address data of `version`.
  _addressWords = version: what: v: let
    f = _family version;
  in
    if isString v
    then f.parse v
    else (_expectVersion version (_expect what _isAddress v)).words;

  # "text/length" -> { text; prefixLength; }, or null when there is no "/".
  _splitCIDR = version: v: let
    m = match "([^/]*)/(.*)" v;
  in
    if m == null
    then null
    else {
      text = elemAt m 0;
      prefixLength = _parseDecimal (_family version).words.totalBits (elemAt m 1);
    };

  # Text without and with the prefix length.
  _compressed = v: (_family v.version).format v.words;
  _cidr = v: "${_compressed v}/${toString v.prefixLength}";

  # x (address or network) lies within network n: same version, at least as long
  # a prefix, and the same network bits. For an address this means its whole
  # network (as given by its prefix length) lies within n.
  _within = n: x:
    n.version
    == x.version
    && x.prefixLength >= n.prefixLength
    && (_wordsOf n).network x.words n.prefixLength == n.words;

  # Total order over all IP data: version, words, prefix length, then networks before addresses.
  _compare = a: b: let
    key = v: let
      v' = _expectIP v;
    in
      [v'.version]
      ++ v'.words
      ++ [
        v'.prefixLength
        (
          if _isNetwork v'
          then 0
          else 1
        )
      ];
  in
    compareLists compare (key a) (key b);

  _sort = sort (a: b: _compare a b < 0);

  # ADDRESS
  # -------

  address = let
    fromString = version: v:
      _guard ["address" "fromString"] (let
        w = (_family version).words;
        cidr =
          if isString v
          then _splitCIDR version v
          else throw "expected an address string, got ${_show v}";
      in
        if cidr == null
        then Address version ((_family version).parse v) w.totalBits
        else Address version ((_family version).parse cidr.text) cidr.prefixLength);

    withPrefixLength = prefixLength: a:
      _guard ["address" "withPrefixLength"] (let
        a' = _expectAddress a;
      in
        Address a'.version a'.words (_expectPrefixLength a'.version prefixLength));

    add = a: n:
      _guard ["address" "add"] (let
        a' = _expectAddress a;
        w = _wordsOf a';
        ws = w.offsetAt a'.words (w.count - 1) n;
      in
        if !(isInt n)
        then throw "offset must be an integer, got ${_show n}"
        else if w.network ws a'.prefixLength != w.network a'.words a'.prefixLength
        then throw "result leaves the network ${_cidr (Network a'.version (w.network a'.words a'.prefixLength) a'.prefixLength)} of ${_cidr a'}"
        else Address a'.version ws a'.prefixLength);
  in {
    /*
    * Parses an address, optionally with the prefix length of its network.
    * Without "/length" the address is a single host (/32 or /128).
    *
    * Example:
    *   lib.extra.ip.address.fromString 6 "fd00::1/64"
    *     -> { _type = "ip-address"; prefixLength = 64; version = 6; words = [ 64768 0 0 0 0 0 0 1 ]; }
    *   lib.extra.ip.toCIDR (lib.extra.ip.address.fromString 4 "10.0.0.1") -> "10.0.0.1/32"
    *
    * Edge cases:
    * - Host bits are allowed; use network.fromCIDR for a network.
    */
    inherit fromString;

    /*
    * Builds address data from an address (plain string or address data) and a prefix length.
    *
    * Example:
    *   lib.extra.ip.address.fromParts 6 "fd00::1" 64 == lib.extra.ip.address.fromString 6 "fd00::1/64" -> true
    *
    * Implementation:
    * - The prefix length of given address data is replaced.
    */
    fromParts = version: addr: prefixLength:
      _guard ["address" "fromParts"] (
        Address version (_addressWords version "IP address string or address data" addr) (_expectPrefixLength version prefixLength)
      );

    /*
    * Builds a single-host address from a word vector / a non-negative integer.
    *
    * Example:
    *   lib.extra.ip.toCompressed (lib.extra.ip.address.fromWords 4 [ 10 0 0 1 ]) -> "10.0.0.1"
    *   lib.extra.ip.toCompressed (lib.extra.ip.address.fromInt 6 65536) -> "::1:0"
    *
    * Implementation:
    * - fromInt divides repeatedly by the word base, least significant word first.
    */
    fromWords = version: ws:
      _guard ["address" "fromWords"] (let
        w = (_family version).words;
      in
        if w.isValid ws
        then Address version ws w.totalBits
        else throw "expected ${toString w.count} integers in [0, ${toString w.max}], got ${_show ws}");

    fromInt = version: n:
      _guard ["address" "fromInt"] (let
        w = (_family version).words;
        digits =
          foldl'
          (st: _: {
            n = st.n / w.base;
            ws = [(mod st.n w.base)] ++ st.ws;
          })
          {
            inherit n;
            ws = [];
          }
          (genList (i: i) w.count);
      in
        if !(isInt n) || n < 0
        then throw "expected a non-negative integer, got ${_show n}"
        else if digits.n != 0
        then throw "${toString n} exceeds the IPv${toString version} address space"
        else Address version digits.ws w.totalBits);

    /*
    * Re-validates untrusted plain data (e.g. after builtins.fromJSON).
    *
    * Example:
    *   lib.extra.ip.address.fromData (builtins.fromJSON (builtins.toJSON a)) == a -> true
    */
    fromData = v: _guard ["address" "fromData"] (_expectAddress v);

    /*
    * Checks, without throwing, whether fromString accepts a value.
    *
    * Example:
    *   lib.extra.ip.address.isParsable 4 "10.0.0.1/24" -> true
    *   lib.extra.ip.address.isParsable 4 "10.0.0.256" -> false
    */
    isParsable = version: v: _succeeds (fromString version v);

    /*
    * Each word of the address as text, most significant first.
    *
    * Example:
    *   lib.extra.ip.address.toGroups (lib.extra.ip.address.fromString 6 "2001:db8::1")
    *     -> [ "2001" "db8" "0" "0" "0" "0" "0" "1" ]
    */
    toGroups = a:
      _guard ["address" "toGroups"] (let
        a' = _expectAddress a;
      in
        map (_family a'.version).group.text a'.words);

    /*
    * The numeric value of the address (the prefix length is ignored).
    *
    * Example:
    *   lib.extra.ip.address.toInt (lib.extra.ip.address.fromString 4 "10.0.0.1/8") -> 167772161
    *
    * Edge cases:
    * - Throws for IPv6 addresses that do not fit into a 64-bit Nix integer.
    */
    toInt = a:
      _guard ["address" "toInt"] (let
        a' = _expectAddress a;
        w = _wordsOf a';
      in
        foldl'
        (acc: x:
          if acc > (maxInt - x) / w.base
          then throw "${_compressed a'} does not fit into a 64-bit Nix integer"
          else acc * w.base + x)
        0
        a'.words);

    /*
    * The same address with another prefix length; singleHostRoute uses the full
    * length (/32, /128), as needed for gateways, DNS servers and peer endpoints.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.address.singleHostRoute (lib.extra.ip.address.fromString 6 "fd00::1/64")) -> "fd00::1/128"
    *   lib.extra.ip.toCIDR (lib.extra.ip.address.withPrefixLength 48 (lib.extra.ip.address.fromString 6 "fd00::1/64")) -> "fd00::1/48"
    */
    inherit withPrefixLength;
    singleHostRoute = a:
      _guard ["address" "singleHostRoute"] (let
        a' = _expectAddress a;
      in
        Address a'.version a'.words (_wordsOf a').totalBits);

    /*
    * The network the address is on, and the host part (as a single-host address).
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.address.getNetwork (lib.extra.ip.address.fromString 6 "fd00::1/64")) -> "fd00::/64"
    *   lib.extra.ip.toCompressed (lib.extra.ip.address.getHostPart (lib.extra.ip.address.fromString 4 "192.168.1.10/24")) -> "0.0.0.10"
    */
    getNetwork = a:
      _guard ["address" "getNetwork"] (let
        a' = _expectAddress a;
      in
        Network a'.version ((_wordsOf a').network a'.words a'.prefixLength) a'.prefixLength);
    getHostPart = a:
      _guard ["address" "getHostPart"] (let
        a' = _expectAddress a;
        w = _wordsOf a';
      in
        Address a'.version (w.host a'.words a'.prefixLength) w.totalBits);

    /*
    * Adds / subtracts an offset, or steps to the next / previous address,
    * staying within the address' network.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.address.next (lib.extra.ip.address.fromString 6 "fd00::1/64")) -> "fd00::2/64"
    *   lib.extra.ip.toCIDR (lib.extra.ip.address.add (lib.extra.ip.address.fromString 4 "10.0.0.255/16") 1) -> "10.0.1.0/16"
    *
    * Edge cases:
    * - Throws when the result leaves the network. A single host (/32, /128) is
    *   its own network, so stepping it always throws; widen it first with
    *   withPrefixLength (e.g. 0 for the whole address space).
    */
    inherit add;
    subtract = a: n: _guard ["address" "subtract"] (add a (0 - n));
    next = a: _guard ["address" "next"] (add a 1);
    prev = a: _guard ["address" "prev"] (add a (-1));

    /*
    * Loads a JSON file holding a list of address strings and/or address data.
    *
    * Example:
    *   lib.extra.ip.address.importJSON 6 ./hosts.json  # [ "fd00::1/64", "fd00::2", ... ]
    */
    importJSON = version: path:
      map
      (v:
        if isString v
        then fromString version v
        else _guard ["address" "importJSON"] (_expectVersion version (_expectAddress v)))
      (importJSON path);
  };

  # NETWORK
  # -------

  network = let
    fromParts = version: prefix: prefixLength:
      _guard ["network" "fromParts"] (let
        f = _family version;
        ws =
          if isString prefix
          then f.parse (f.expandPrefix prefix)
          else _addressWords version "prefix string or IP address data" prefix;
        len = _expectPrefixLength version prefixLength;
      in
        if f.words.hasHostBits ws len
        then throw "prefix ${_show prefix} has host bits set for /${toString len}; the network is ${f.format (f.words.network ws len)}/${toString len}"
        else Network version ws len);

    fromCIDR = version: v:
      _guard ["network" "fromCIDR"] (let
        cidr =
          if isString v
          then _splitCIDR version v
          else null;
      in
        if cidr == null
        then throw "expected 'prefix/length', got ${_show v}"
        else fromParts version cidr.text cidr.prefixLength);

    # Adjacent network of the same length: +/-1 at the least significant network bit.
    step = name: delta: n:
      _guard ["network" name] (let
        n' = _expectNetwork n;
        w = _wordsOf n';
        u = w.unitAt n'.prefixLength;
      in
        if n'.prefixLength == 0
        then throw "a /0 has no neighbouring network"
        else Network n'.version (w.offsetAt n'.words u.i (delta * u.unit)) n'.prefixLength);

    subnetAt = n: newLen: i:
      _guard ["network" "subnetAt"] (let
        n' = _expectNetwork n;
        w = _wordsOf n';
        diff = newLen - n'.prefixLength;
      in
        if !(isInt newLen) || diff < 1 || newLen > w.totalBits
        then throw "new prefix length must be an integer in (${toString n'.prefixLength}, ${toString w.totalBits}], got ${_show newLen}"
        else if diff > 32
        then throw "at most 32 extra prefix bits are supported"
        else if !(isInt i) || i < 0 || i >= pow2 diff
        then throw "index must be in [0, ${toString (pow2 diff - 1)}], got ${_show i}"
        else let
          u = w.unitAt newLen;
        in
          Network n'.version (w.offsetAt n'.words u.i (i * u.unit)) newLen);

    # Minimal cover of sorted networks of one version.
    aggregateSorted = ns: let
      # CIDR blocks are nested or disjoint, so the last kept network suffices.
      denested = reverseList (foldl'
        (out: n:
          if out != [] && _within (head out) n
          then out
          else [n] ++ out)
        []
        ns);

      # a is the lower and b the upper half of the same /(len - 1)
      siblings = a: b: let
        w = _wordsOf a;
      in
        a.prefixLength
        == b.prefixLength
        && a.prefixLength > 0
        && !(w.hasHostBits a.words (a.prefixLength - 1))
        && w.network b.words (a.prefixLength - 1) == a.words;

      push = stack: n:
        if stack != [] && siblings (head stack) n
        then push (tail stack) (Network n.version (head stack).words (n.prefixLength - 1))
        else [n] ++ stack;
    in
      reverseList (foldl' push [] denested);
  in {
    /*
    * Parses CIDR notation into network data.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.network.fromCIDR 6 "fda0:9527:6cee::/48") -> "fda0:9527:6cee::/48"
    *
    * Edge cases:
    * - Throws if host bits are set and names the correct network.
    * - IPv6 prefixes may be abbreviated: "fda0:9527:68ee/48".
    */
    inherit fromCIDR;

    /*
    * Builds network data from a prefix (string or address data) and a prefix length.
    *
    * Example:
    *   lib.extra.ip.network.fromParts 6 "fda0:9527:6cee" 48 == lib.extra.ip.network.fromCIDR 6 "fda0:9527:6cee::/48" -> true
    *
    * Implementation:
    * - IPv6 strings may be abbreviated: missing trailing groups are zero.
    * - The prefix length of given address data is ignored.
    */
    inherit fromParts;

    /*
    * Re-validates untrusted plain network data (e.g. after builtins.fromJSON).
    *
    * Example:
    *   lib.extra.ip.network.fromData (builtins.fromJSON (builtins.toJSON n)) == n -> true
    */
    fromData = v: _guard ["network" "fromData"] (_expectNetwork v);

    /*
    * Checks, without throwing, whether fromCIDR accepts a value.
    *
    * Example:
    *   lib.extra.ip.network.isParsable 4 "10.0.0.0/8" -> true
    *   lib.extra.ip.network.isParsable 4 "10.0.0.1/8" -> false
    */
    isParsable = version: v: _succeeds (fromCIDR version v);

    /*
    * The groups touched by the prefix, rounded up to whole groups.
    *
    * Example:
    *   lib.extra.ip.network.toPrefixGroups (lib.extra.ip.network.fromCIDR 6 "fda0:9527:6cee::/48") -> "fda0:9527:6cee"
    *
    * Edge cases:
    * - For IPv6, fromParts accepts the result again; IPv4 has no abbreviated syntax.
    */
    toPrefixGroups = n:
      _guard ["network" "toPrefixGroups"] (let
        n' = _expectNetwork n;
        f = _family n'.version;
      in
        concatMapStringsSep f.group.separator f.group.text
        (take ((n'.prefixLength + f.words.bits - 1) / f.words.bits) n'.words));

    /*
    * First (network) and last address of a network, as addresses on that network.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.network.getLastAddress (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/30")) -> "10.0.0.3/30"
    */
    getNetworkAddress = n:
      _guard ["network" "getNetworkAddress"] (let
        n' = _expectNetwork n;
      in
        Address n'.version n'.words n'.prefixLength);
    getLastAddress = n:
      _guard ["network" "getLastAddress"] (let
        n' = _expectNetwork n;
      in
        Address n'.version ((_wordsOf n').last n'.words n'.prefixLength) n'.prefixLength);

    /*
    * Network mask (network bits set) and host mask (host bits set), as single-host addresses.
    *
    * Example:
    *   lib.extra.ip.toCompressed (lib.extra.ip.network.getNetmask (lib.extra.ip.network.fromCIDR 4 "192.168.4.0/22")) -> "255.255.252.0"
    *   lib.extra.ip.toCompressed (lib.extra.ip.network.getHostmask (lib.extra.ip.network.fromCIDR 4 "192.168.4.0/22")) -> "0.0.3.255"
    */
    getNetmask = n:
      _guard ["network" "getNetmask"] (let
        n' = _expectNetwork n;
        w = _wordsOf n';
      in
        Address n'.version (map (m: w.max - m) (w.hostMask n'.prefixLength)) w.totalBits);
    getHostmask = n:
      _guard ["network" "getHostmask"] (let
        n' = _expectNetwork n;
        w = _wordsOf n';
      in
        Address n'.version (w.hostMask n'.prefixLength) w.totalBits);

    /*
    * Number of host bits (the counterpart of prefixLength).
    *
    * Example:
    *   lib.extra.ip.network.getHostLength (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/8") -> 24
    */
    getHostLength = n:
      _guard ["network" "getHostLength"] (let
        n' = _expectNetwork n;
      in
        (_wordsOf n').totalBits - n'.prefixLength);

    /*
    * The address of a host on the network, from its host part (e.g. an IPv6
    * interface identifier) as a plain string or address data.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.network.hostAddress (lib.extra.ip.network.fromCIDR 6 "fda0:9527:68ee:4f8a::/64") "::20:61fc:3462:bf01")
    *     -> "fda0:9527:68ee:4f8a:20:61fc:3462:bf01/64"
    *
    * Implementation:
    * - Adds the host words to the network words (no carry: the parts do not overlap).
    *
    * Edge cases:
    * - Throws if the host part does not fit into the network's host bits.
    */
    hostAddress = n: hostPart:
      _guard ["network" "hostAddress"] (let
        n' = _expectNetwork n;
        w = _wordsOf n';
        hs = _addressWords n'.version "host part string or IP address data" hostPart;
      in
        if any (x: x != 0) (w.network hs n'.prefixLength)
        then throw "host part ${_show hostPart} does not fit into the ${toString (w.totalBits - n'.prefixLength)} host bits of /${toString n'.prefixLength}"
        else Address n'.version (genList (i: elemAt n'.words i + elemAt hs i) w.count) n'.prefixLength);

    /*
    * Whether network n contains x: a network, or an address together with its
    * whole network (so fd00::/64 contains fd00::1/64 and fd00::1/128, not fd00::1/48).
    *
    * Example:
    *   lib.extra.ip.network.contains (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/8") (lib.extra.ip.address.fromString 4 "10.1.2.3") -> true
    *
    * Edge cases:
    * - Data of different versions is never contained (false, not an error).
    */
    contains = n: x: _guard ["network" "contains"] (_within (_expectNetwork n) (_expectIP x));

    /*
    * Whether two networks share at least one address.
    *
    * Example:
    *   lib.extra.ip.network.overlaps (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/8") (lib.extra.ip.network.fromCIDR 4 "10.2.0.0/16") -> true
    *
    * Implementation:
    * - CIDR blocks are nested or disjoint, so overlap means containment either way.
    */
    overlaps = a: b:
      _guard ["network" "overlaps"] (let
        a' = _expectNetwork a;
        b' = _expectNetwork b;
      in
        _within a' b' || _within b' a');

    /*
    * The adjacent network of the same length after / before the given one.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.network.next (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/24")) -> "10.0.1.0/24"
    */
    next = step "next" 1;
    prev = step "prev" (-1);

    /*
    * The enclosing network with a shorter prefix length.
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.network.supernet (lib.extra.ip.network.fromCIDR 4 "10.1.2.0/24") 8) -> "10.0.0.0/8"
    */
    supernet = n: newLen:
      _guard ["network" "supernet"] (let
        n' = _expectNetwork n;
      in
        if !(isInt newLen) || newLen < 0 || newLen >= n'.prefixLength
        then throw "new prefix length must be an integer in [0, ${toString (n'.prefixLength - 1)}], got ${_show newLen}"
        else Network n'.version ((_wordsOf n').network n'.words newLen) newLen);

    /*
    * The i-th (0-based) /newLen subnet of a network, in O(1).
    *
    * Example:
    *   lib.extra.ip.toCIDR (lib.extra.ip.network.subnetAt (lib.extra.ip.network.fromCIDR 6 "fda0:9527:68ee::/48") 64 (lib.fromHexString "4f8a"))
    *     -> "fda0:9527:68ee:4f8a::/64"
    *
    * Edge cases:
    * - At most 32 extra prefix bits, so i always fits into a Nix integer.
    */
    inherit subnetAt;

    /*
    * All /newLen subnets of a network, in ascending order.
    *
    * Example:
    *   map lib.extra.ip.toCIDR (lib.extra.ip.network.subnets (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/23") 24)
    *     -> [ "10.0.0.0/24" "10.0.1.0/24" ]
    *
    * Edge cases:
    * - Refuses more than 2^16 results; use subnetAt instead.
    */
    subnets = n: newLen:
      _guard ["network" "subnets"] (let
        n' = _expectNetwork n;
        w = _wordsOf n';
        diff = newLen - n'.prefixLength;
      in
        if !(isInt newLen) || diff < 1 || newLen > w.totalBits
        then throw "new prefix length must be an integer in (${toString n'.prefixLength}, ${toString w.totalBits}], got ${_show newLen}"
        else if diff > 16
        then throw "refusing to enumerate more than 2^16 subnets; use subnetAt"
        else genList (subnetAt n' newLen) (pow2 diff));

    /*
    * Minimal list of networks covering exactly the same addresses as the input
    * networks (any versions), sorted ascending.
    *
    * Example:
    *   map lib.extra.ip.toCIDR (lib.extra.ip.network.aggregate (map (lib.extra.ip.network.fromCIDR 4) [ "10.0.1.0/24" "10.0.0.0/24" ]))
    *     -> [ "10.0.0.0/23" ]
    *
    * Implementation:
    * - Per version: sort, drop nested networks, then join sibling halves.
    *
    * Edge cases:
    * - Accepts networks only; convert addresses with address.getNetwork
    *   (after address.singleHostRoute for the host itself).
    */
    aggregate = ns:
      _guard ["network" "aggregate"] (let
        ns' = map _expectNetwork ns;
      in
        concatLists (map
          (version: aggregateSorted (_sort (filter (n: n.version == version) ns')))
          _versions));

    /*
    * Loads a JSON file holding a list of CIDR strings and/or network data.
    *
    * Example:
    *   lib.extra.ip.network.importJSON 4 ./bogons.json  # [ "10.0.0.0/8", ... ]
    */
    importJSON = version: path:
      map
      (v:
        if isString v
        then fromCIDR version v
        else _guard ["network" "importJSON"] (_expectVersion version (_expectNetwork v)))
      (importJSON path);
  };

  # TYPES
  # -----

  types = let
    inherit (super.types) coercedTo mkOptionType str;

    dataType = name: description: check:
      mkOptionType {
        inherit name description check;
        descriptionClass = "noun";
        merge = super.options.mergeEqualOption;
      };

    # Data of one version passing `check`; strings are coerced with `parse version`.
    coerced = name: description: check: parse: version: let
      v = toString version;
    in
      coercedTo str (parse version)
      (dataType "ipv${v}${name}" "IPv${v} ${description}" (x: check x && x.version == version));
  in {
    /**
    * Option types for IP data.
    *
    * addressData / networkData:
    *   - Accept data of any version; merge by equality.
    *
    * address / singleHostAddress / network (take a version):
    *   - Accept data of that version, or a string coerced with
    *     address.fromString / network.fromCIDR.
    *   - singleHostAddress only accepts /32 or /128 addresses (gateways, DNS
    *     servers, peer endpoints); "fd00::1/64" is rejected, "fd00::1" accepted.
    *
    * Example:
    *   options.dns = lib.mkOption { type = lib.types.listOf (lib.extra.ip.types.singleHostAddress 6); };
    *   options.addresses = lib.mkOption { type = lib.types.listOf (lib.extra.ip.types.address 6); };
    */
    addressData = dataType "ipAddress" "IP address" _isAddress;
    networkData = dataType "ipNetwork" "IP network" _isNetwork;

    address = coerced "Address" "address" _isAddress address.fromString;
    singleHostAddress =
      coerced "SingleHostAddress" "single-host address"
      (x: _isAddress x && x.prefixLength == (_wordsOf x).totalBits)
      address.fromString;
    network = coerced "Network" "network" _isNetwork network.fromCIDR;
  };
in {
  inherit address network types;

  /*
  * Exhaustive elimination over address and network data of any version.
  * Both handlers are mandatory (a missing/extra name is a Nix argument error).
  *
  * Example:
  *   lib.extra.ip.caseOf { address = a: "host"; network = n: "net"; } (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/8")
  *     -> "net"
  */
  caseOf = handlers: v: builtins.addErrorContext "while evaluating ${scope}.caseOf" (_caseOf handlers v);

  /*
  * Kind and version predicates; never throw.
  *
  * Example:
  *   lib.extra.ip.isAddress (lib.extra.ip.address.fromString 6 "::1") -> true
  *   lib.extra.ip.isIPv4 (lib.extra.ip.network.fromCIDR 6 "::/0") -> false
  */
  isAddress = _isAddress;
  isNetwork = _isNetwork;
  isIP = _isIP;
  isIPv4 = v: _isIP v && v.version == 4;
  isIPv6 = v: _isIP v && v.version == 6;

  /*
  * IP version (4 or 6) and prefix length of any IP data.
  *
  * Example:
  *   lib.extra.ip.getVersion (lib.extra.ip.address.fromString 6 "::1") -> 6
  *   lib.extra.ip.getPrefixLength (lib.extra.ip.address.fromString 6 "::1") -> 128
  */
  getVersion = v: _guard ["getVersion"] (_expectIP v).version;
  getPrefixLength = v: _guard ["getPrefixLength"] (_expectIP v).prefixLength;

  /*
  * "address/length" in canonical form, for addresses and networks.
  *
  * Example:
  *   lib.extra.ip.toCIDR (lib.extra.ip.address.fromString 4 "10.0.0.1") -> "10.0.0.1/32"
  *   lib.extra.ip.toCIDR (lib.extra.ip.network.fromCIDR 6 "fda0:9527:68ee::/48") -> "fda0:9527:68ee::/48"
  */
  toCIDR = v: _guard ["toCIDR"] (_cidr (_expectIP v));

  /*
  * The address part without prefix length: canonical (RFC 5952) or fully expanded.
  * Compare toCompressed results to compare addresses regardless of prefix length.
  *
  * Example:
  *   lib.extra.ip.toCompressed (lib.extra.ip.address.fromString 6 "2001:DB8:0:0::1/64") -> "2001:db8::1"
  *   lib.extra.ip.toExploded (lib.extra.ip.address.fromString 6 "2001:db8::1") -> "2001:0db8:0000:0000:0000:0000:0000:0001"
  *
  * Edge cases:
  * - toExploded equals toCompressed for IPv4.
  */
  toCompressed = v: _guard ["toCompressed"] (_compressed (_expectIP v));
  toExploded = v:
    _guard ["toExploded"] (let
      v' = _expectIP v;
      g = (_family v'.version).group;
    in
      concatMapStringsSep g.separator g.full v'.words);

  /*
  * The address part as the host of a URI (RFC 3986): IPv6 in brackets, IPv4 as is.
  *
  * Example:
  *   lib.extra.ip.toURIHost (lib.extra.ip.address.fromString 6 "2001:DB8::1/64") -> "[2001:db8::1]"
  *   lib.extra.ip.toURIHost (lib.extra.ip.address.fromString 4 "10.0.0.1") -> "10.0.0.1"
  */
  toURIHost = v:
    _guard ["toURIHost"] (let
      v' = _expectIP v;
    in
      if v'.version == 6
      then "[${_compressed v'}]"
      else _compressed v');

  /*
  * Total order over addresses and networks: version, address, prefix length,
  * then networks before addresses.
  *
  * Example:
  *   map lib.extra.ip.toCIDR (lib.extra.ip.sort [ (lib.extra.ip.address.fromString 4 "10.0.0.1") (lib.extra.ip.network.fromCIDR 4 "10.0.0.0/8") ])
  *     -> [ "10.0.0.0/8" "10.0.0.1/32" ]
  */
  compare = a: b: _guard ["compare"] (_compare a b);
  sort = vs: _guard ["sort"] (_sort vs);
}
