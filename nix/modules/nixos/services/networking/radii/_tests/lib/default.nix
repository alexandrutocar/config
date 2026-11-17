# RADII LIBRARY
# -------------
# Pure functions of the typed site table, shared by the module (derived
# values, per-host assertions) and the flake check (the whole table), so both
# see the same site.
{lib}: let
  inherit (lib.extra) ip;
  inherit (lib.attrsets) attrNames attrValues filterAttrs mapAttrs mapAttrsToList;
  inherit (lib.lists) concatLists concatMap drop filter foldl' groupBy head imap0 length optional;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.trivial) max;

  describe = concatStringsSep ", ";

  isHub = host: host.endpoints != [];

  # The host's /48, plus its host address as a /128 when it lies outside.
  ownedNetworks = host: let
    outside = host.prefix == null || !(ip.network.contains host.prefix host.hostAddress);
  in
    optional (host.prefix != null) host.prefix
    ++ optional outside (ip.address.getNetwork host.hostAddress);

  # Endpoints of `hub` that `host` can reach: addresses inside one of its
  # availableNetworks. DNS names are kept; they are resolved at runtime.
  candidatesFor = host: hub:
    filter (endpoint: !(ip.isAddress endpoint) || ip.network.containsAny host.availableNetworks endpoint)
    hub.endpoints;

  # Where `hub` listens for `peer`, or null (not a hub, or no base port).
  portOf = hub: peer:
    if isHub hub && hub.basePort != null
    then hub.basePort + peer.id
    else null;

  validPort = port: port != null && port >= 1 && port <= 65535;

  # DERIVATION
  # ----------
  deriveHosts = mapAttrs (_: host:
    host
    // {
      role =
        if isHub host
        then "hub"
        else "spoke";
      ownedNetworks = ownedNetworks host;
    });

  derive = site: self: let
    hosts = deriveHosts site;
    me = hosts.${self};

    # A spoke connects to every hub; a hub connects to every host.
    connects = peer: peer.name != me.name && (isHub me || isHub peer);
  in {
    inherit hosts;
    self = me;
    peers = mapAttrs (_: peer:
      peer
      // {
        # This host's port for the tunnel to `peer`; null = any port.
        listenPort = portOf me peer;
        # The port of `peer`'s endpoints for this host; null for a spoke.
        endpointPort = portOf peer me;
        # `peer`'s endpoints this host can reach; empty for a spoke.
        candidates =
          if isHub peer
          then candidatesFor me peer
          else [];
      })
    (filterAttrs (_: connects) hosts);
  };

  # CHECKS
  # ------
  # Each returns messages; an empty list means the check passed.

  # The whole table, as every host sees it.
  checkSite = site: let
    hosts = attrValues (deriveHosts site);
    hubs = filter isHub hosts;
    highestId = foldl' max 0 (map (host: host.id) hosts);

    # Values held by more than one host, compared by their text.
    duplicates = what: valueOf:
      hosts
      |> groupBy valueOf
      |> filterAttrs (_: holders: length holders > 1)
      |> mapAttrsToList (value: holders: "${what} ${value} is used by ${describe (map (host: host.name) holders)}");

    # Owned networks of different hosts must not share an address: each
    # range has exactly one owner, who validates where it comes from.
    owned = concatMap (host:
      map (network: {
        inherit (host) name;
        inherit network;
      })
      host.ownedNetworks)
    hosts;
    overlaps =
      owned
      |> imap0 (index: a:
        drop (index + 1) owned
        |> filter (b: b.name != a.name && ip.network.overlaps a.network b.network)
        |> map (b: "${ip.toCIDR a.network} (${a.name}) overlaps ${ip.toCIDR b.network} (${b.name})"))
      |> concatLists;
  in
    duplicates "id" (host: toString host.id)
    ++ duplicates "host address" (host: ip.toCompressed host.hostAddress)
    ++ duplicates "public key" (host: host.publicKey)
    ++ overlaps
    ++ (hosts
      |> filter (host: host.kind == "device" && isHub host)
      |> map (host: "${host.name} is a device with endpoints: devices cannot be hubs"))
    ++ (hubs
      |> filter (hub: hub.basePort == null)
      |> map (hub: "hub ${hub.name} has no basePort"))
    ++ (hubs
      |> filter (hub: hub.basePort != null && hub.basePort + highestId > 65535)
      |> map (hub: "hub ${hub.name}: basePort ${toString hub.basePort} plus the highest id ${toString highestId} exceeds 65535"));

  # One host's view of the table: { errors; warnings; }.
  checkHost = site: self:
    if !(site ? ${self})
    then {
      errors = ["${self} is not in the site table (${describe (attrNames site)})"];
      warnings = [];
    }
    else let
      derived = derive site self;
      me = derived.self;
      hubs = filterAttrs (_: peer: peer.role == "hub") derived.peers;
      reachable = attrNames (filterAttrs (_: hub: hub.candidates != []) hubs);

      showPort = port:
        if port == null
        then "no port (basePort unset)"
        else toString port;

      invalidPorts =
        attrValues derived.peers
        |> concatMap (peer:
          optional (me.role == "hub" && !(validPort peer.listenPort))
          "${self} listens for ${peer.name} on ${showPort peer.listenPort}"
          ++ optional (peer.role == "hub" && !(validPort peer.endpointPort))
          "${peer.name} listens for ${self} on ${showPort peer.endpointPort}");
    in {
      errors =
        optional (me.role == "spoke" && reachable == []) (
          if hubs == {}
          then "${self} reaches no hub: the site table has none"
          else "${self} reaches no hub: no endpoint of ${describe (attrNames hubs)} lies in its availableNetworks"
        )
        ++ map (message: "invalid port: ${message}") invalidPorts;

      warnings =
        optional (me.role == "spoke" && length reachable == 1)
        "${self} reaches only one hub (${head reachable}): it has no failover";
    };
in {
  inherit derive checkSite checkHost;
}
