/*
* URL parts as algebraic data types, built on lib.extra.ip.
*
*   Scheme    = { name, defaultPort, secure }       predefined in `schemes`
*   Host      = Name    { name }                    reg-name, lowercased
*             | Address { address }                 IP address data, /32 or /128
*   UserInfo  = { name, password }                  stored decoded
*   Authority = { userInfo, host, port }            [ userinfo "@" ] host [ ":" port ]
*   Origin    = { scheme, host, port }              scheme "://" host [ ":" port ]
*   Interface = { address, port }                   a socket address: IP address and port
*
* - Data is minimal and function-free: plain attrsets tagged with `_type`.
* - Functions take the "-Like" union of a part, so callers pass strings or IP data:
*     HostLike      = String | IpAddress | Host
*                     strings in URI host syntax: "example.com", "10.0.0.1", "[::1]"
*     AddressLike   = String | IpAddress | Host (address)
*                     address position: "::1", "[::1]", "10.0.0.1"
*     PortLike      = Int | String | null
*     UserLike      = String | { name; password ? null; } | UserInfo | null
*     SchemeLike    = String | Scheme       strings are looked up in `schemes`
*     AuthorityLike = String | Authority | Origin | Interface
* - The IP version follows from the syntax (brackets or ':' mean IPv6), so no
*   function takes a version except interface.wildcard and the option types.
* - Not supported: IPv6 zone identifiers, IPvFuture literals, internationalized
*   names (pass them as punycode "xn--..."), opaque URLs without "//".
*
*
*                toOrigin scheme                toInterface
*   Authority  ─────────────────▶  Origin  ─────────────────▶  Interface
*       ▲  ◀─────────────────────    │  ◀───────────────────     │
*       │        toAuthority         │    toOrigin scheme        │
*       └────────────────────────────┴───────────────────────────┘
*                        toAuthority (from Interface)
*
* Naming as in lib.extra.ip:
*   from*  build data          to*   render text
*   get*   extract a part      with* copy with one field replaced
*   is*    predicates          plain verbs: operations (normalize, equals, ...)
*/
final: super: {scope}: let
  ip = final.extra.ip;

  inherit (builtins) attrNames fromJSON isAttrs listToAttrs;
  inherit (super.lists) all concatLists elem elemAt foldl' genList head isList last length;
  inherit (super.strings) concatMapStrings concatMapStringsSep concatStringsSep fixedWidthString hasInfix hasPrefix hasSuffix isString match optionalString splitString stringLength stringToCharacters substring toLower;
  inherit (super.trivial) deepSeq fromHexString isBool isInt mod toHexString warnIf;
  inherit (super.types) isType setType;

  _show = super.generators.toPretty {};

  # HELPERS
  # -------

  _strict = v: deepSeq v v;
  _succeeds = v: (builtins.tryEval (deepSeq v true)).success;

  # Adds "while evaluating <scope>.<path>" to errors and forces the result.
  _guard = path: v:
    builtins.addErrorContext
    "while evaluating ${scope}.${concatStringsSep "." path}"
    (_strict v);

  _expect = what: pred: v:
    if pred v
    then v
    else throw "expected ${what}, got ${_show v}";

  # BYTES AND PERCENT-ENCODING
  # --------------------------
  #
  # Nix strings are byte strings. lib.escapeURL leaves bytes >= 0x80 unescaped,
  # so non-ASCII text is encoded here, byte by byte.

  _hex2 = n: fixedWidthString 2 "0" (toHexString n);
  _hex4 = n: fixedWidthString 4 "0" (toHexString n);

  # The UTF-8 encoding of a code point (1 to 0x10FFFF, no surrogates).
  _chr = cp:
    if cp < 65536
    then fromJSON ''"\u${_hex4 cp}"''
    else let
      c = cp - 65536;
    in
      fromJSON ''"\u${_hex4 (55296 + c / 1024)}\u${_hex4 (56320 + mod c 1024)}"'';

  # One-byte string -> byte value, for every byte that valid UTF-8 can contain.
  # High bytes are cut out of the encodings of suitable code points.
  _byteValues = let
    byte = s: i: substring i 1 s;
    ascii =
      genList (i: {
        b = _chr (i + 1);
        v = i + 1;
      })
      127;
    continuation =
      genList (i: {
        b = byte (_chr (128 + i)) 1;
        v = 128 + i;
      })
      64;
    lead2 =
      genList (i: {
        b = byte (_chr ((i + 2) * 64)) 0;
        v = 194 + i;
      })
      30;
    lead3 =
      genList (i: {
        b =
          byte (_chr (
            if i == 0
            then 2048
            else i * 4096
          ))
          0;
        v = 224 + i;
      })
      16;
    lead4 =
      genList (i: {
        b =
          byte (_chr (
            if i == 0
            then 65536
            else i * 262144
          ))
          0;
        v = 240 + i;
      })
      5;
  in
    listToAttrs (map (e: {
      name = e.b;
      value = e.v;
    }) (ascii ++ continuation ++ lead2 ++ lead3 ++ lead4));

  # Percent-encodes everything except unreserved characters (RFC 3986, 2.3).
  _percentEncode = what: s:
    concatMapStrings
    (c:
      if match "[A-Za-z0-9._~-]" c != null
      then c
      else "%${_hex2 (_byteValues.${c} or (throw "${what} is not valid UTF-8 text"))}")
    (stringToCharacters s);

  # Decodes a list of byte values as UTF-8, rejecting overlong forms, surrogates and NUL.
  _decodeUTF8 = what: bs: let
    n = length bs;
    at = i: elemAt bs i;
    fail = throw "${what} contains percent-escapes that are not valid UTF-8";
    cont = i: i < n && at i >= 128 && at i < 192;
    go = i:
      if i >= n
      then ""
      else let
        b = at i;
        seq =
          if b < 128
          then {
            len = 1;
            cp = b;
          }
          else if b >= 194 && b < 224 && cont (i + 1)
          then {
            len = 2;
            cp = (b - 192) * 64 + at (i + 1) - 128;
          }
          else if b >= 224 && b < 240 && cont (i + 1) && cont (i + 2)
          then {
            len = 3;
            cp = (b - 224) * 4096 + (at (i + 1) - 128) * 64 + at (i + 2) - 128;
          }
          else if b >= 240 && b < 245 && cont (i + 1) && cont (i + 2) && cont (i + 3)
          then {
            len = 4;
            cp = (b - 240) * 262144 + (at (i + 1) - 128) * 4096 + (at (i + 2) - 128) * 64 + at (i + 3) - 128;
          }
          else fail;
        bad =
          (seq.len == 3 && seq.cp < 2048)
          || (seq.len == 4 && (seq.cp < 65536 || seq.cp > 1114111))
          || (seq.cp >= 55296 && seq.cp < 57344);
      in
        if bad
        then fail
        else if seq.cp == 0
        then throw "${what} contains %00, which a Nix string cannot hold"
        else _chr seq.cp + go (i + seq.len);
  in
    go 0;

  _isPercentValid = s: match "([^%]|%[0-9A-Fa-f]{2})*" s != null;

  _percentDecode = what: s: let
    step = st: p:
      if isList p
      then st // {bytes = st.bytes ++ [(fromHexString (head p))];}
      else if p == ""
      then st
      else {
        out = st.out + _decodeUTF8 what st.bytes + p;
        bytes = [];
      };
    r =
      foldl' step {
        out = "";
        bytes = [];
      }
      (builtins.split "%([0-9A-Fa-f]{2})" s);
  in
    if !(_isPercentValid s)
    then throw "${what} has a '%' that does not start a %XX escape"
    else r.out + _decodeUTF8 what r.bytes;

  # Characters a URI may contain at all (RFC 3986, unreserved / reserved / '%').
  _isURIText = s: match "[][A-Za-z0-9._~:/?#@!$&'()*+,;=%-]*" s != null;

  # PORTS
  # -----

  _isPortNumber = p: isInt p && p >= 0 && p <= 65535;

  # Strict decimal: no sign, no leading zeros, at most 65535.
  _parsePort = s:
    if match "[0-9]+" s == null
    then throw "'${s}' is not a port number"
    else if s != "0" && hasPrefix "0" s
    then throw "port '${s}' has leading zeros"
    else if stringLength s > 5 || fromJSON s > 65535
    then throw "port ${s} is outside [0, 65535]"
    else fromJSON s;

  _port = p:
    if p == null
    then null
    else if isInt p
    then
      if _isPortNumber p
      then p
      else throw "port ${toString p} is outside [0, 65535]"
    else if isString p
    then _parsePort p
    else throw "expected a port number, got ${_show p}";

  # Port text after ':' in a URI: null (no ':') or "" (empty, RFC 3986 3.2.3) mean none.
  _portText = t:
    if t == null || t == ""
    then null
    else _parsePort t;

  # DATA
  # ----

  _tags = {
    scheme = "url-scheme";
    name = "url-host-name";
    address = "url-host-address";
    userInfo = "url-userinfo";
    authority = "url-authority";
    origin = "url-origin";
    interface = "url-interface";
  };

  # Raw constructors: no validation; the from* functions validate.
  Scheme = name: defaultPort: secure: setType _tags.scheme {inherit defaultPort name secure;};
  Name = name: setType _tags.name {inherit name;};
  HostAddress = address: setType _tags.address {inherit address;};
  UserInfo = name: password: setType _tags.userInfo {inherit name password;};
  Authority = userInfo: host: port: setType _tags.authority {inherit host port userInfo;};
  Origin = scheme: host: port: setType _tags.origin {inherit host port scheme;};
  Interface = address: port: setType _tags.interface {inherit address port;};

  # SCHEMES
  # -------

  _isSchemeName = n: isString n && match "[a-z][a-z0-9+.-]*" n != null;

  _isScheme = v:
    isType _tags.scheme v
    && attrNames v == ["_type" "defaultPort" "name" "secure"]
    && _isSchemeName v.name
    && (v.defaultPort == null || _isPortNumber v.defaultPort)
    && isBool v.secure;

  # The registry, honouring an override of `schemes` through a lib overlay.
  _registry = ((final.extra or {}).url or {}).schemes or schemes;

  _scheme = v:
    if isString v
    then let
      n = toLower v;
    in
      if !(_isSchemeName n)
      then throw "'${v}' is not a valid URI scheme name"
      else _registry.${n} or (throw "unknown scheme '${n}'; use ${scope}.scheme.custom or add it to ${scope}.schemes")
    else _expect "a scheme name or scheme data" _isScheme v;

  schemes =
    builtins.mapAttrs (name: s: Scheme name s.port s.secure)
    {
      http = {
        port = 80;
        secure = false;
      }; # RFC 9110
      https = {
        port = 443;
        secure = true;
      }; # RFC 9110
      ws = {
        port = 80;
        secure = false;
      }; # RFC 6455
      wss = {
        port = 443;
        secure = true;
      }; # RFC 6455
      ftp = {
        port = 21;
        secure = false;
      }; # RFC 1738
      ftps = {
        port = 990;
        secure = true;
      }; # RFC 4217 (implicit TLS)
      sftp = {
        port = 22;
        secure = true;
      };
      ssh = {
        port = 22;
        secure = true;
      };
      "git+ssh" = {
        port = 22;
        secure = true;
      };
      git = {
        port = 9418;
        secure = false;
      };
      rsync = {
        port = 873;
        secure = false;
      }; # RFC 5781
      telnet = {
        port = 23;
        secure = false;
      }; # RFC 4248
      dns = {
        port = 53;
        secure = false;
      }; # RFC 4501
      ldap = {
        port = 389;
        secure = false;
      }; # RFC 4516
      ldaps = {
        port = 636;
        secure = true;
      };
      smtp = {
        port = 25;
        secure = false;
      };
      imap = {
        port = 143;
        secure = false;
      }; # RFC 5092
      imaps = {
        port = 993;
        secure = true;
      };
      pop = {
        port = 110;
        secure = false;
      }; # RFC 2384
      xmpp = {
        port = 5222;
        secure = false;
      }; # RFC 5122
      irc = {
        port = 6667;
        secure = false;
      };
      ircs = {
        port = 6697;
        secure = true;
      };
      sip = {
        port = 5060;
        secure = false;
      }; # RFC 3261
      sips = {
        port = 5061;
        secure = true;
      }; # RFC 3261
      rtsp = {
        port = 554;
        secure = false;
      }; # RFC 7826
      nntp = {
        port = 119;
        secure = false;
      }; # RFC 5538
      coap = {
        port = 5683;
        secure = false;
      }; # RFC 7252
      coaps = {
        port = 5684;
        secure = true;
      }; # RFC 7252
      mqtt = {
        port = 1883;
        secure = false;
      };
      mqtts = {
        port = 8883;
        secure = true;
      };
      amqp = {
        port = 5672;
        secure = false;
      };
      amqps = {
        port = 5671;
        secure = true;
      };
      nats = {
        port = 4222;
        secure = false;
      };
      redis = {
        port = 6379;
        secure = false;
      };
      rediss = {
        port = 6379;
        secure = true;
      };
      postgresql = {
        port = 5432;
        secure = false;
      };
      postgres = {
        port = 5432;
        secure = false;
      };
      mysql = {
        port = 3306;
        secure = false;
      };
      mongodb = {
        port = 27017;
        secure = false;
      };
      vnc = {
        port = 5900;
        secure = false;
      }; # RFC 7869
      smb = {
        port = 445;
        secure = false;
      };
      nfs = {
        port = 2049;
        secure = false;
      }; # RFC 2224
    };

  # HOSTS
  # -----

  # A DNS-style name: labels of 1-63 letters, digits, '-' or '_', not starting or
  # ending with '-'; at most 253 characters; an optional trailing dot. A last
  # label that is numeric (or 0x-hex) would read as an IPv4 address, as the
  # WHATWG URL standard does, so it is rejected ("127.1", "1.2.3.4.5").
  _checkName = s: let
    n = toLower s;
    bare =
      if hasSuffix "." n
      then substring 0 (stringLength n - 1) n
      else n;
    labels = splitString "." bare;
  in
    if bare == ""
    then throw "a host name must not be empty"
    else if stringLength bare > 253
    then throw "host name '${s}' is longer than 253 characters"
    else if !(all (l: match "[a-z0-9_]([a-z0-9_-]{0,61}[a-z0-9_])?" l != null) labels)
    then throw "'${s}' is not a valid host name: labels are 1-63 letters, digits, '-' or '_', not starting or ending with '-' (internationalized names as punycode)"
    else if match "[0-9]+|0x[0-9a-f]*" (last labels) != null
    then throw "'${s}' ends in a numeric label, so it reads as a malformed IPv4 address rather than a name"
    else n;

  _isFullLength = a:
    ip.getPrefixLength a
    == (
      if ip.isIPv6 a
      then 128
      else 32
    );

  _isName = v:
    isType _tags.name v
    && attrNames v == ["_type" "name"]
    && isString v.name
    && (let r = builtins.tryEval (_checkName v.name); in r.success && r.value == v.name);
  _isHostAddress = v:
    isType _tags.address v
    && attrNames v == ["_type" "address"]
    && ip.isAddress v.address
    && _isFullLength v.address;
  _isHost = v: _isName v || _isHostAddress v;

  _caseOfHost = {
    name,
    address,
  }: h:
    if _isName h
    then name h
    else if _isHostAddress h
    then address h
    else throw "expected host data, got ${_show h}";

  # The inside of "[...]": an IPv6 address.
  _ipv6Literal = inner:
    if hasPrefix "v" inner || hasPrefix "V" inner
    then throw "IPvFuture literals ([v...]) are not supported"
    else if hasInfix "%" inner
    then throw "IPv6 zone identifiers ([...%25zone]) are not supported"
    else if match "[0-9A-Fa-f:.]+" inner == null
    then throw "'[${inner}]' is not an IPv6 literal"
    else ip.address.fromString 6 inner;

  _hostFromString = s:
    if !(isString s)
    then throw "expected a host string, got ${_show s}"
    else if s == ""
    then throw "a host must not be empty"
    else let
      br = match "[[](.*)[]]" s;
    in
      if br != null
      then HostAddress (_ipv6Literal (head br))
      else if hasInfix ":" s
      then throw "'${s}' contains ':'; write an IPv6 address in brackets ([::1]) and pass the port separately"
      else if match "[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+" s != null
      then HostAddress (ip.address.fromString 4 s)
      else Name (_checkName s);

  _host = v:
    if isString v
    then _hostFromString v
    else if ip.isAddress v
    then HostAddress (ip.address.singleHostRoute v)
    else if ip.isNetwork v
    then throw "expected a host, got the network ${ip.toCIDR v}"
    else _expect "a host string, IP address data or host data" _isHost v;

  _hostText = _caseOfHost {
    name = h: h.name;
    address = h: ip.toURIHost h.address;
  };
  _hostBare = _caseOfHost {
    name = h: h.name;
    address = h: ip.toCompressed h.address;
  };

  # USERINFO
  # --------
  #
  # Error messages never echo a password.

  _isUserInfo = v:
    isType _tags.userInfo v
    && attrNames v == ["_type" "name" "password"]
    && isString v.name
    && (v.password == null || isString v.password)
    && (v.name != "" || v.password != null);

  _userInfo = v:
    if v == null
    then null
    else if isString v
    then
      if v == ""
      then throw "the user name is empty; use null for no userinfo"
      else UserInfo v null
    else if _isUserInfo v
    then v
    else if isAttrs v && !(v ? _type)
    then
      if v == {}
      then null
      else let
        unknown = attrNames (removeAttrs v ["name" "password"]);
        password = v.password or null;
      in
        if unknown != []
        then throw "unexpected user attributes: ${concatStringsSep ", " unknown}; expected { name; password ? null; }"
        else if !(isString (v.name or null))
        then throw "the user needs a string `name`"
        else if password != null && !(isString password)
        then throw "the user's `password` must be a string or null"
        else if v.name == "" && password == null
        then throw "the user name is empty; use null for no userinfo"
        else UserInfo v.name password
    else throw "expected a user name, { name; password ? null; }, userinfo data or null";

  _userInfoText = u:
    _percentEncode "the user name" u.name
    + optionalString (u.password != null) ":${_percentEncode "the password" u.password}";

  # "name[:password]" as found before '@'; split at the first ':'.
  _userInfoFromText = t: let
    m = match "([^:]*)(:(.*))?" t;
  in
    if match "[A-Za-z0-9._~!$&'()*+,;=:%-]*" t == null
    then throw "the userinfo contains characters that must be percent-encoded (e.g. '@' as %40)"
    else if t == ""
    then throw "the userinfo before '@' is empty"
    else
      UserInfo (_percentDecode "the user name" (elemAt m 0))
      (
        if elemAt m 1 == null
        then null
        else _percentDecode "the password" (elemAt m 2)
      );

  # AUTHORITY
  # ---------

  _isAuthority = v:
    isType _tags.authority v
    && attrNames v == ["_type" "host" "port" "userInfo"]
    && _isHost v.host
    && (v.port == null || _isPortNumber v.port)
    && (v.userInfo == null || _isUserInfo v.userInfo);

  # "host[:port]" -> { host; port; } with host text and port text (null, "" or digits).
  _splitHostPort = s: let
    bracketed = hasPrefix "[" s;
    m =
      if bracketed
      then match "([[].*[]])(:(.*))?" s
      else match "([^:]*)(:(.*))?" s;
  in
    if m == null
    then
      if bracketed
      then throw "'${s}': expected '[IPv6]' optionally followed by ':port'"
      else throw "'${s}' has more than one ':'; write an IPv6 address in brackets ([::1]:443)"
    else {
      host = elemAt m 0;
      port = elemAt m 2;
    };

  _authorityFromString = s:
    if !(isString s)
    then throw "expected an authority string, got ${_show s}"
    else if !(_isURIText s) || match ".*[/?#].*" s != null
    then throw "an authority must not contain '/', '?', '#', whitespace or other characters outside a URI"
    else let
      at = match "(.*)@([^@]*)" s;
      hp = _splitHostPort (
        if at == null
        then s
        else elemAt at 1
      );
    in
      Authority
      (
        if at == null
        then null
        else _userInfoFromText (elemAt at 0)
      )
      (_hostFromString hp.host)
      (_portText hp.port);

  _authorityText = a:
    optionalString (a.userInfo != null) "${_userInfoText a.userInfo}@"
    + _hostText a.host
    + optionalString (a.port != null) ":${toString a.port}";

  # ORIGIN
  # ------

  _isOrigin = v:
    isType _tags.origin v
    && attrNames v == ["_type" "host" "port" "scheme"]
    && _isScheme v.scheme
    && _isHost v.host
    && (v.port == null || _isPortNumber v.port);

  # "scheme://authority rest" -> parts; the whole text must be URI characters.
  _splitURL = s: let
    m = match "([A-Za-z][A-Za-z0-9+.-]*)://([^/?#]*)(.*)" s;
  in
    if !(isString s)
    then throw "expected a URL string, got ${_show s}"
    else if !(_isURIText s)
    then throw "the URL contains whitespace or characters that must be percent-encoded"
    else if m == null
    then throw "expected 'scheme://host...', got '${s}'; URLs without an authority (mailto:, urn:) have no origin"
    else {
      scheme = _scheme (elemAt m 0);
      authority = _authorityFromString (elemAt m 1);
      rest = elemAt m 2;
    };

  _originFromString = s: let
    u = _splitURL s;
  in
    if u.authority.userInfo != null
    then throw "an origin carries no userinfo; use origin.fromURL to drop it"
    else if u.rest != "" && u.rest != "/"
    then throw "an origin has no path, query or fragment, got '${u.rest}'; use origin.fromURL to drop them"
    else Origin u.scheme u.authority.host u.authority.port;

  _origin = v:
    if isString v
    then _originFromString v
    else _expect "an origin string or origin data" _isOrigin v;

  _effectivePort = o:
    if o.port != null
    then o.port
    else o.scheme.defaultPort;

  _normalizeOrigin = o:
    if o.port != null && o.port == o.scheme.defaultPort
    then Origin o.scheme o.host null
    else o;

  _originText = o: "${o.scheme.name}://${_hostText o.host}${optionalString (o.port != null) ":${toString o.port}"}";

  # INTERFACE
  # ---------

  _isInterface = v:
    isType _tags.interface v
    && attrNames v == ["_type" "address" "port"]
    && ip.isAddress v.address
    && _isFullLength v.address
    && _isPortNumber v.port;

  # AddressLike -> single-host IP address data. Strings take a plain address:
  # bare or bracketed IPv6, IPv4; no prefix length, no names.
  _ipAddress = v:
    if isString v
    then let
      br = match "[[](.*)[]]" v;
      t =
        if br == null
        then v
        else head br;
    in
      if t == ""
      then throw "an address must not be empty"
      else if hasInfix "/" t
      then throw "'${v}' has a prefix length; an interface takes a plain address"
      else if hasInfix "%" t
      then throw "IPv6 zone identifiers are not supported, got '${v}'"
      else if hasInfix ":" t
      then ip.address.fromString 6 t
      else if br != null
      then throw "only IPv6 addresses are written in brackets, got '${v}'"
      else if match "[0-9.]+" t == null
      then throw "'${v}' is not an IP address; an interface needs one (resolve names elsewhere)"
      else ip.address.fromString 4 t
    else if ip.isAddress v
    then ip.address.singleHostRoute v
    else if ip.isNetwork v
    then throw "expected an address, got the network ${ip.toCIDR v}"
    else if _isHostAddress v
    then v.address
    else if _isName v
    then throw "an interface needs an IP address, got the host name ${v.name}"
    else throw "expected an address string or IP address data, got ${_show v}";

  _requirePort = what: p:
    if p == null
    then throw "${what} needs a port"
    else _port p;

  _interfaceFromString = s:
    if !(isString s)
    then throw "expected an 'address:port' string, got ${_show s}"
    else let
      hp = _splitHostPort s;
    in
      if hp.port == null || hp.port == ""
      then throw "'${s}' has no port; expected 'address:port' ([::1]:53, 10.0.0.1:53)"
      else Interface (_ipAddress hp.host) (_parsePort hp.port);

  _interfaceFromNLnetLabs = s: let
    m = match "([^@]*)@([^@]*)" s;
  in
    if !(isString s)
    then throw "expected an 'address@port' string, got ${_show s}"
    else if hasInfix "#" s
    then throw "'${s}' has a TLS authentication name (#name), which is not part of an interface"
    else if m == null
    then throw "'${s}' has no port; expected 'address@port' (::1@53, 10.0.0.1@53)"
    else Interface (_ipAddress (elemAt m 0)) (_parsePort (elemAt m 1));

  _interface = v:
    if isString v
    then _interfaceFromString v
    else _expect "an 'address:port' string or interface data" _isInterface v;

  _interfaceText = i: "${ip.toURIHost i.address}:${toString i.port}";

  _hostToInterface = what: host: port:
    _caseOfHost {
      name = h: throw "${what} has the host name ${h.name}; an interface needs an IP address";
      address = h:
        if port == null
        then throw "${what} has no port; an interface needs one"
        else Interface h.address port;
    }
    host;

  # Conversions between the records.
  _authorityToOrigin = scheme: a: Origin (_scheme scheme) a.host a.port;
  _originToAuthority = o: Authority null o.host o.port;
  _interfaceToAuthority = i: Authority null (HostAddress i.address) i.port;
  _interfaceToOrigin = scheme: i: Origin (_scheme scheme) (HostAddress i.address) i.port;

  _authority = v:
    if isString v
    then _authorityFromString v
    else if _isAuthority v
    then v
    else if _isOrigin v
    then _originToAuthority v
    else if _isInterface v
    then _interfaceToAuthority v
    else throw "expected an authority string, authority, origin or interface data, got ${_show v}";

  # MODULES
  # -------

  scheme = {
    /*
    * A scheme from its name (looked up in `schemes`, case-insensitively) or
    * scheme data.
    *
    * Example:
    *   lib.extra.url.scheme.from "HTTPS" == lib.extra.url.schemes.https -> true
    *
    * Edge cases:
    * - Unknown names throw; build those with scheme.custom.
    */
    from = v: _guard ["scheme" "from"] (_scheme v);

    /*
    * A scheme that is not in `schemes`.
    *
    * Example:
    *   lib.extra.url.scheme.custom { name = "gemini"; defaultPort = 1965; secure = true; }
    */
    custom = {
      name,
      defaultPort ? null,
      secure ? false,
    }:
      _guard ["scheme" "custom"] (
        if !(_isSchemeName name)
        then throw "'${toString name}' is not a valid lowercase URI scheme name"
        else if !(isBool secure)
        then throw "`secure` must be a Boolean"
        else Scheme name (_port defaultPort) secure
      );

    fromData = v: _guard ["scheme" "fromData"] (_expect "scheme data" _isScheme v);
    isKnown = n: isString n && _registry ? ${toLower n};
    getDefaultPort = v: _guard ["scheme" "getDefaultPort"] (_scheme v).defaultPort;
    isSecure = v: _guard ["scheme" "isSecure"] (_scheme v).secure;
    toString = v: _guard ["scheme" "toString"] (_scheme v).name;
  };

  host = {
    /*
    * Host data from a name, an IP literal or IP address data.
    *
    * Example:
    *   lib.extra.url.host.toString (lib.extra.url.host.from "[2001:DB8::1]") -> "[2001:db8::1]"
    *   lib.extra.url.host.toString (lib.extra.url.host.from (lib.extra.ip.address.fromString 6 "fd00::1/64")) -> "[fd00::1]"
    *
    * Edge cases:
    * - Names are lowercased; a trailing dot is kept.
    * - IP data loses its prefix length; networks are rejected.
    * - A bare IPv6 address ("::1") and "host:port" are rejected.
    */
    from = v: _guard ["host" "from"] (_host v);
    fromString = s: _guard ["host" "fromString"] (_hostFromString s);
    fromAddress = a:
      _guard ["host" "fromAddress"] (
        if ip.isAddress a
        then _host a
        else throw "expected IP address data, got ${_show a}"
      );
    fromData = v: _guard ["host" "fromData"] (_expect "host data" _isHost v);
    isParsable = v: _succeeds (_host v);

    isName = _isName;
    isAddress = _isHostAddress;
    caseOf = handlers: h: builtins.addErrorContext "while evaluating ${scope}.host.caseOf" (_caseOfHost handlers h);

    getName = v:
      _guard ["host" "getName"] (_caseOfHost {
        name = h: h.name;
        address = h: throw "${_hostText h} is an IP address, not a name";
      } (_host v));
    getAddress = v:
      _guard ["host" "getAddress"] (_caseOfHost {
        name = h: throw "${h.name} is a name, not an IP address";
        address = h: h.address;
      } (_host v));

    /*
    * The host as in a URI ("[::1]"), or bare ("::1") for configs that take
    * the port in a separate field.
    */
    toString = v: _guard ["host" "toString"] (_hostText (_host v));
    toBare = v: _guard ["host" "toBare"] (_hostBare (_host v));
  };

  port = {
    /*
    * A validated port number, or null.
    *
    * Example:
    *   lib.extra.url.port.from "8080" -> 8080
    *
    * Edge cases:
    * - Strings must be plain decimal without leading zeros ("08080" throws).
    */
    from = p: _guard ["port" "from"] (_port p);
    isValid = p: _isPortNumber p || _succeeds (_port p) && p != null;
  };

  userInfo = {
    /*
    * Userinfo data from a name, { name; password ? null; } or null.
    *
    * Example:
    *   lib.extra.url.userInfo.toString { name = "bob"; password = "p@ss wörd"; } -> "bob:p%40ss%20w%C3%B6rd"
    *
    * Edge cases:
    * - null and {} mean no userinfo; an empty name needs a password.
    * - Error messages never contain the password.
    */
    from = v: _guard ["userInfo" "from"] (_userInfo v);
    fromData = v: _guard ["userInfo" "fromData"] (_expect "userinfo data" _isUserInfo v);
    toString = v:
      _guard ["userInfo" "toString"] (let
        u = _userInfo v;
      in
        if u == null
        then ""
        else _userInfoText u);
  };

  authority = {
    /*
    * authority = [ userinfo "@" ] host [ ":" port ]
    *
    * Example:
    *   lib.extra.url.authority.toString (lib.extra.url.authority.fromParts "::1" 22 "bob") -> throws (bare IPv6)
    *   lib.extra.url.authority.toString (lib.extra.url.authority.fromParts "[::1]" 22 "bob") -> "bob@[::1]:22"
    *   lib.extra.url.authority.toString (lib.extra.url.authority.fromString "a%40b:pw@Example.COM:") -> "a%40b:pw@example.com"
    *
    * Edge cases:
    * - fromString splits userinfo at the last '@' and name from password at the first ':'.
    * - An empty port ("host:") means no port, as RFC 3986 allows.
    */
    fromParts = h: p: u: _guard ["authority" "fromParts"] (Authority (_userInfo u) (_host h) (_port p));
    fromString = s: _guard ["authority" "fromString"] (_authorityFromString s);
    from = v: _guard ["authority" "from"] (_authority v);
    fromData = v: _guard ["authority" "fromData"] (_expect "authority data" _isAuthority v);
    isParsable = v: _succeeds (_authorityFromString v);

    getHost = v: _guard ["authority" "getHost"] (_authority v).host;
    getPort = v: _guard ["authority" "getPort"] (_authority v).port;
    getUserInfo = v: _guard ["authority" "getUserInfo"] (_authority v).userInfo;

    withHost = h: v: _guard ["authority" "withHost"] (let a = _authority v; in Authority a.userInfo (_host h) a.port);
    withPort = p: v: _guard ["authority" "withPort"] (let a = _authority v; in Authority a.userInfo a.host (_port p));
    withUserInfo = u: v: _guard ["authority" "withUserInfo"] (let a = _authority v; in Authority (_userInfo u) a.host a.port);
    withoutUserInfo = v: _guard ["authority" "withoutUserInfo"] (let a = _authority v; in Authority null a.host a.port);

    toString = v: _guard ["authority" "toString"] (_authorityText (_authority v));

    /*
    * The origin under a scheme (the userinfo is dropped) / the interface
    * (needs an IP host and a port).
    */
    toOrigin = s: v: _guard ["authority" "toOrigin"] (_authorityToOrigin s (_authority v));
    toInterface = v:
      _guard ["authority" "toInterface"] (let
        a = _authority v;
      in
        _hostToInterface (_authorityText (Authority null a.host a.port)) a.host a.port);
  };

  origin = {
    /*
    * origin = scheme "://" host [ ":" port ]; never carries userinfo.
    *
    * Example:
    *   lib.extra.url.origin.toString (lib.extra.url.origin.fromParts "HTTPS" (lib.extra.ip.address.fromString 6 "fd00::1/64") 8443)
    *     -> "https://[fd00::1]:8443"
    *   lib.extra.url.origin.toString (lib.extra.url.origin.fromURL "https://bob@example.com:443/x?y#z") -> "https://example.com:443"
    *
    * Edge cases:
    * - The port is kept as given; normalize drops one equal to the default.
    * - fromString accepts a single trailing "/", nothing else after the authority.
    * - Unknown schemes throw; pass scheme.custom data to fromParts.
    */
    fromParts = s: h: p: _guard ["origin" "fromParts"] (Origin (_scheme s) (_host h) (_port p));
    fromString = s: _guard ["origin" "fromString"] (_originFromString s);
    fromURL = s:
      _guard ["origin" "fromURL"] (let
        u = _splitURL s;
      in
        Origin u.scheme u.authority.host u.authority.port);
    fromData = v: _guard ["origin" "fromData"] (_expect "origin data" _isOrigin v);
    isParsable = v: _succeeds (_originFromString v);

    getScheme = v: _guard ["origin" "getScheme"] (_origin v).scheme;
    getHost = v: _guard ["origin" "getHost"] (_origin v).host;
    # Effective port: explicit, else the scheme's default (null for a custom scheme without one).
    getPort = v: _guard ["origin" "getPort"] (_effectivePort (_origin v));
    getExplicitPort = v: _guard ["origin" "getExplicitPort"] (_origin v).port;

    withScheme = s: v: _guard ["origin" "withScheme"] (let o = _origin v; in Origin (_scheme s) o.host o.port);
    withHost = h: v: _guard ["origin" "withHost"] (let o = _origin v; in Origin o.scheme (_host h) o.port);
    withPort = p: v: _guard ["origin" "withPort"] (let o = _origin v; in Origin o.scheme o.host (_port p));

    normalize = v: _guard ["origin" "normalize"] (_normalizeOrigin (_origin v));

    /*
    * Same origin (RFC 6454): scheme, host and effective port.
    *
    * Example:
    *   lib.extra.url.origin.equals "https://Example.com" "https://example.com:443/" -> true
    */
    equals = a: b: _guard ["origin" "equals"] (_normalizeOrigin (_origin a) == _normalizeOrigin (_origin b));

    toString = v: _guard ["origin" "toString"] (_originText (_origin v));
    toAuthority = v: _guard ["origin" "toAuthority"] (_originToAuthority (_origin v));
    toInterface = v:
      _guard ["origin" "toInterface"] (let
        o = _origin v;
      in
        _hostToInterface (_originText o) o.host (_effectivePort o));
  };

  interface = {
    /*
    * A socket address: an IP address and a port.
    *
    * Example:
    *   lib.extra.url.interface.toString (lib.extra.url.interface.fromParts "fd00::1" 51820) -> "[fd00::1]:51820"
    *   lib.extra.url.interface.toNLnetLabs (lib.extra.url.interface.fromParts (lib.extra.ip.address.fromString 6 "fd00::1/64") 53)
    *     -> "fd00::1@53"
    *
    * Uses:
    * - toString: WireGuard endpoints, systemd ListenStream=, nginx listen.
    * - toNLnetLabs: Unbound interface/outgoing-interface/forward-addr, NSD ip-address.
    *
    * Edge cases:
    * - The port is required. Names are rejected: an interface is an IP address.
    * - Strings may be bare or bracketed IPv6, but carry no prefix length;
    *   IP data loses its prefix length.
    */
    fromParts = a: p: _guard ["interface" "fromParts"] (Interface (_ipAddress a) (_requirePort "an interface" p));
    fromString = s: _guard ["interface" "fromString"] (_interfaceFromString s);
    fromNLnetLabs = s: _guard ["interface" "fromNLnetLabs"] (_interfaceFromNLnetLabs s);
    fromData = v: _guard ["interface" "fromData"] (_expect "interface data" _isInterface v);
    isParsable = v: _succeeds (_interfaceFromString v);

    /*
    * The unspecified address of a version, for listening on all addresses.
    *
    * Example:
    *   lib.extra.url.interface.toString (lib.extra.url.interface.wildcard 6 53) -> "[::]:53"
    */
    wildcard = version: p:
      _guard ["interface" "wildcard"] (
        if version == 4
        then Interface (ip.address.fromString 4 "0.0.0.0") (_requirePort "an interface" p)
        else if version == 6
        then Interface (ip.address.fromString 6 "::") (_requirePort "an interface" p)
        else throw "unsupported IP version ${_show version}; expected 4 or 6"
      );
    isWildcard = v:
      _guard ["interface" "isWildcard"] (let
        i = _interface v;
      in
        all (x: x == 0) i.address.words);

    getAddress = v: _guard ["interface" "getAddress"] (_interface v).address;
    getPort = v: _guard ["interface" "getPort"] (_interface v).port;
    getVersion = v: _guard ["interface" "getVersion"] (ip.getVersion (_interface v).address);

    withAddress = a: v: _guard ["interface" "withAddress"] (Interface (_ipAddress a) (_interface v).port);
    withPort = p: v: _guard ["interface" "withPort"] (Interface (_interface v).address (_requirePort "an interface" p));

    toString = v: _guard ["interface" "toString"] (_interfaceText (_interface v));

    /*
    * NLnet Labs syntax (Unbound, NSD): "address@port", IPv6 without brackets;
    * the TLS variant appends the authentication name for forward-addr.
    *
    * Example:
    *   lib.extra.url.interface.toNLnetLabsTLS "cloudflare-dns.com" "[2606:4700:4700::1111]:853"
    *     -> "2606:4700:4700::1111@853#cloudflare-dns.com"
    */
    toNLnetLabs = v:
      _guard ["interface" "toNLnetLabs"] (let
        i = _interface v;
      in "${ip.toCompressed i.address}@${toString i.port}");
    toNLnetLabsTLS = name: v:
      _guard ["interface" "toNLnetLabsTLS"] (let
        i = _interface v;
      in
        if !(isString name)
        then throw "the TLS authentication name must be a string, got ${_show name}"
        else "${ip.toCompressed i.address}@${toString i.port}#${_checkName name}");

    toAuthority = v: _guard ["interface" "toAuthority"] (_interfaceToAuthority (_interface v));
    toOrigin = s: v: _guard ["interface" "toOrigin"] (_interfaceToOrigin s (_interface v));
  };

  # URL
  # ---
  # Segments, query values and fragments given as structured data are encoded;
  # given as a string they must already be URI text.
  _rawText = what: extra: s:
    if !(isString s)
    then throw "${what} must be a string, got ${_show s}"
    else if match "[A-Za-z0-9._~!$&'()*+,;=:@%${extra}-]*" s == null
    then throw "${what} '${s}' contains characters that must be percent-encoded; pass structured data to have them encoded"
    else if !(_isPercentValid s)
    then throw "${what} '${s}' has a '%' that does not start a %XX escape"
    else s;

  _queryValue = v:
    if isString v
    then _percentEncode "a query value" v
    else if isInt v
    then toString v
    else if isBool v
    then
      if v
      then "true"
      else "false"
    else throw "a query value must be a string, integer, Boolean, null or a list of those, got ${_show v}";

  _queryPair = name: value:
    if !(isString name) || name == ""
    then throw "query names must be non-empty strings, got ${_show name}"
    else if value == null
    then [(_percentEncode "a query name" name)]
    else if isList value
    then concatLists (map (_queryPair name) value)
    else ["${_percentEncode "a query name" name}=${_queryValue value}"];

  _pathText = path:
    if path == null || path == "" || path == []
    then ""
    else if isList path
    then concatMapStrings (seg: "/${_percentEncode "a path segment" (_expect "a path segment string" isString seg)}") path
    else if isString path && !(hasPrefix "/" path)
    then throw "a path after an authority must start with '/', got '${path}'"
    else _rawText "the path" "/" path;

  _queryText = q:
    if q == null
    then ""
    else if isString q
    then "?${_rawText "the query" "/?" q}"
    else let
      pairs =
        if isList q
        then concatLists (map (p: _queryPair (p.name or null) (p.value or null)) q)
        else if isAttrs q
        then concatLists (map (n: _queryPair n q.${n}) (attrNames q))
        else throw "the query must be a string, an attribute set or a list of { name; value; }, got ${_show q}";
    in
      optionalString (pairs != []) "?${concatStringsSep "&" pairs}";

  _fragmentText = f:
    if f == null
    then ""
    else "#${_rawText "the fragment" "/?" f}";

  mkURL = {
    scheme,
    host,
    port ? null,
    user ? null,
    path ? null,
    query ? null,
    fragment ? null,
  }:
    _guard ["mkURL"] (
      "${(_scheme scheme).name}://${_authorityText (Authority (_userInfo user) (_host host) (_port port))}"
      + _pathText path
      + _queryText query
      + _fragmentText fragment
    );

  # TYPES
  # -----
  types = let
    inherit (super.types) coercedTo either mkOptionType str;
    inherit (super.options) mergeEqualOption showOption;

    # Merges by equality; `warning` returns a message for a merged value, or null.
    dataType = {
      name,
      description,
      check,
      warning ? (_: null),
    }:
      mkOptionType {
        inherit name description check;
        descriptionClass = "noun";
        merge = loc: defs: let
          v = mergeEqualOption loc defs;
          w = warning v;
        in
          warnIf (w != null) "${showOption loc}: ${toString w}" v;
      };

    expectPolicy = p:
      if elem p ["any" "warn" "default"]
      then p
      else throw "`port` must be \"any\", \"warn\" or \"default\", got ${_show p}";

    expectPorts = ps:
      if isList ps && all _isPortNumber ps
      then ps
      else throw "`allowedPorts` must be a list of port numbers, got ${_show ps}";

    # Port policy for a port under a scheme (data or null).
    policy = {
      port,
      allowedPorts,
    }: let
      p = expectPolicy port;
      allowed = expectPorts allowedPorts;
      fine = s: x: x == null || s == null || s.defaultPort == null || x == s.defaultPort || elem x allowed;
    in {
      check = s: x: p != "default" || fine s x;
      warning = s: x:
        if p == "warn" && !(fine s x)
        then
          "port ${toString x} is not the default port ${toString s.defaultPort} of ${s.name}"
          + optionalString (allowed != []) " nor one of the allowed ports ${concatMapStringsSep ", " toString allowed}"
        else null;
      describe = s:
        optionalString (p == "default" && s != null && s.defaultPort != null)
        " on port ${concatMapStringsSep " or " toString ([s.defaultPort] ++ allowed)}";
    };

    # `within` -> list of network data; versions follow from the text unless given.
    scopesOf = version: within: let
      one = n:
        if isString n
        then
          ip.network.fromCIDR (
            if version != null
            then version
            else if hasInfix ":" n
            then 6
            else 4
          )
          n
        else if ip.isNetwork n
        then n
        else throw "`within` takes CIDR text or IP network data, got ${_show n}";
    in
      if within == null
      then []
      else if !(isList within)
      then [(one within)]
      else if within == []
      then throw "`within` must not be an empty list; use null for no constraint"
      else map one within;

    describeScopes = ns:
      if ns == []
      then ""
      else if length ns == 1
      then " within ${ip.toCIDR (head ns)}"
      else " within one of ${concatMapStringsSep ", " ip.toCIDR ns}";

    hostWith = {
      names ? true,
      addresses ? true,
      version ? null,
    }:
      builtins.addErrorContext "while evaluating ${scope}.types.hostWith" (
        if !names && !addresses
        then throw "a host type must allow names, addresses or both"
        else if version != null && version != 4 && version != 6
        then throw "unsupported IP version ${_show version}; expected 4 or 6"
        else
          coercedTo (either str ip.types.addressData) _host
          (dataType {
            name = "urlHost";
            description = concatStringsSep " or " (
              (
                if names
                then ["host name"]
                else []
              )
              ++ (
                if addresses
                then [
                  "${
                    if version == null
                    then "IP"
                    else "IPv${toString version}"
                  } address"
                ]
                else []
              )
            );
            check = x:
              (names && _isName x)
              || (addresses && _isHostAddress x && (version == null || ip.getVersion x.address == version));
          })
      );

    originWith = {
      schemes ? null,
      port ? "warn",
      allowedPorts ? [],
    }:
      builtins.addErrorContext "while evaluating ${scope}.types.originWith" (let
        allowedSchemes =
          if schemes == null
          then null
          else
            map (s: (_scheme s).name) (
              if isList schemes
              then schemes
              else [schemes]
            );
        pol = policy {inherit port allowedPorts;};
        only = optionalString (allowedSchemes != null) " with scheme ${concatStringsSep " or " allowedSchemes}";
        single =
          if allowedSchemes != null && length allowedSchemes == 1
          then _scheme (head allowedSchemes)
          else null;
      in
        coercedTo str _originFromString
        (dataType {
          name = "urlOrigin";
          description = "origin${only}${pol.describe single}";
          check = x:
            _isOrigin x
            && (allowedSchemes == null || elem x.scheme.name allowedSchemes)
            && pol.check x.scheme x.port;
          warning = x: pol.warning x.scheme x.port;
        }));

    interfaceWith = {
      version ? null,
      within ? null,
      scheme ? null,
      port ? "warn",
      allowedPorts ? [],
    }:
      builtins.addErrorContext "while evaluating ${scope}.types.interfaceWith" (let
        s =
          if scheme == null
          then null
          else _scheme scheme;
        scopes = scopesOf version within;
        pol = policy {inherit port allowedPorts;};
        v = optionalString (version != null) "IPv${toString version} ";
        forScheme = optionalString (s != null) " for ${s.name}";
      in
        if version != null && version != 4 && version != 6
        then throw "unsupported IP version ${_show version}; expected 4 or 6"
        else
          coercedTo str _interfaceFromString
          (dataType {
            name = "urlInterface";
            description = "${v}interface (address:port)${forScheme}${describeScopes scopes}${pol.describe s}";
            check = x:
              _isInterface x
              && (version == null || ip.getVersion x.address == version)
              && (scopes == [] || ip.network.containsAny scopes x.address)
              && pol.check s x.port;
            warning = x: pol.warning s x.port;
          }));
  in {
    /**
    * Option types for URL parts. Strings are coerced with the matching
    * from* function; hosts also accept IP address data. All merge by equality.
    *
    * hostWith { names ? true; addresses ? true; version ? null; }
    * originWith { schemes ? null; port ? "warn"; allowedPorts ? []; }
    * interfaceWith { version ? null; within ? null; scheme ? null; port ? "warn"; allowedPorts ? []; }
    *   - schemes: one scheme or a list (names or data) the origin may use.
    *   - scheme: the service an interface is for; enables the port policy.
    *   - port: what to do with a port other than the scheme's default:
    *     "any" accepts it, "warn" warns naming the option, "default" rejects it.
    *     allowedPorts are accepted without a warning. Without a scheme
    *     default port, nothing is checked.
    *   - within: as in lib.extra.ip.types; the version follows from the text.
    *
    * scheme / port / authority / host / origin / interface:
    *   - Shorthands for the unconstrained forms (origin and interface still warn).
    *
    * Example:
    *   options.listen = lib.mkOption {
    *     type = lib.types.listOf (lib.extra.url.types.interfaceWith { scheme = "dns"; within = lib.extra.ip.ranges.ipv6.uniqueLocal; });
    *   };
    *   options.publicOrigin = lib.mkOption {
    *     type = lib.extra.url.types.originWith { schemes = "https"; port = "default"; allowedPorts = [ 8443 ]; };
    *   };
    */
    inherit hostWith originWith interfaceWith;

    scheme = coercedTo str _scheme (dataType {
      name = "urlScheme";
      description = "URI scheme";
      check = _isScheme;
    });

    port = coercedTo str _parsePort (dataType {
      name = "urlPort";
      description = "port number (0-65535)";
      check = _isPortNumber;
    });

    authority = coercedTo str _authorityFromString (dataType {
      name = "urlAuthority";
      description = "URI authority ([userinfo@]host[:port])";
      check = _isAuthority;
    });

    host = hostWith {};
    origin = originWith {};
    interface = interfaceWith {};
  };

  _mkOrigin = s: h: p: _guard ["mkOrigin"] (_originText (Origin (_scheme s) (_host h) (_port p)));
in {
  inherit schemes scheme host port userInfo authority origin interface types mkURL;

  /*
  * Shortcuts that return text.
  *
  * Example:
  *   lib.extra.url.mkAuthority "[::1]" 22 { name = "bob"; } -> "bob@[::1]:22"
  *   lib.extra.url.mkOrigin "https" (lib.extra.ip.address.fromString 4 "10.0.0.1/24") null -> "https://10.0.0.1"
  *   lib.extra.url.mkInterface "fd00::1" 51820 -> "[fd00::1]:51820"
  *   lib.extra.url.mkURL { scheme = "https"; host = "example.com"; path = [ "a b" "c" ]; query = { q = "x&y"; }; }
  *     -> "https://example.com/a%20b/c?q=x%26y"
  */
  mkAuthority = h: p: u: _guard ["mkAuthority"] (_authorityText (Authority (_userInfo u) (_host h) (_port p)));
  mkOrigin = _mkOrigin;
  mkInterface = a: p: _guard ["mkInterface"] (_interfaceText (Interface (_ipAddress a) (_requirePort "an interface" p)));
  mkDefaultOrigin = s: h: _mkOrigin s h null;

  /*
  * Kind predicates; never throw.
  */
  isScheme = _isScheme;
  isHost = _isHost;
  isUserInfo = _isUserInfo;
  isAuthority = _isAuthority;
  isOrigin = _isOrigin;
  isInterface = _isInterface;
}
