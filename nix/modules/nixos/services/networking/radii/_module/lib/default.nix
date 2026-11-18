# RADII LIBRARY
# -------------
# Pure functions of the typed site table, shared by the module (derived
# values, tunnels, per-host assertions, device files) and the flake check (the whole
# table), so both see the same site.
{lib}: let
  inherit (lib.extra) ip;
  inherit (lib.attrsets) attrNames attrValues filterAttrs listToAttrs mapAttrs mapAttrsToList;
  inherit (lib.generators) mkKeyValueDefault toINI;
  inherit (lib.lists) concatLists concatMap drop elem filter foldl' groupBy head imap0 imap1 init last length optional optionals range sort sortOn unique;
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

  # An endpoint as WireGuard writes it: IPv6 in brackets, then the port.
  hostText = endpoint:
    if ip.isAddress endpoint
    then ip.toURIHost endpoint
    else endpoint;

  endpointText = endpoint: port: "${hostText endpoint}:${toString port}";

  # PORTS
  # -----
  # The ports `hub` must have open: one per host that can reach it (an
  # endpoint of the hub lies in the host's availableNetworks), sorted. Each
  # is { port; peer; via; }, `via` being the hub's endpoints that peer uses.
  # Empty for a host that is not a hub or is missing from the table.
  inboundPorts = site: hubName:
    if !(site ? ${hubName})
    then []
    else let
      hosts = deriveHosts site;
      hub = hosts.${hubName};
    in
      if !(isHub hub) || hub.basePort == null
      then []
      else
        attrValues hosts
        |> filter (peer: peer.name != hubName && candidatesFor peer hub != [])
        |> map (peer: {
          port = hub.basePort + peer.id;
          peer = peer.name;
          via = map hostText (candidatesFor peer hub);
        })
        |> sortOn (entry: entry.port);

  # The ports a host's openPorts lists, ranges spelled out.
  openPortsOf = host:
    if host.openPorts == null
    then []
    else
      concatMap (entry:
        if builtins.isInt entry
        then [entry]
        else range entry.from entry.to)
      host.openPorts;

  # Ports as a Nix value to paste into openPorts, runs as ranges:
  # [ 50011 [ 50013 50015 ] ].
  showPorts = ports: let
    runs = foldl' (acc: port:
      if acc != [] && (last acc).to + 1 == port
      then init acc ++ [(last acc // {to = port;})]
      else
        acc
        ++ [
          {
            from = port;
            to = port;
          }
        ]) []
    (sort builtins.lessThan (unique ports));

    showRun = run:
      if run.from == run.to
      then toString run.from
      else "[ ${toString run.from} ${toString run.to} ]";
  in
    if runs == []
    then "[ ]"
    else "[ ${concatStringsSep " " (map showRun runs)} ]";

  # TUNNELS
  # -------
  # The tunnel to a peer is named after it: "rd-" plus the peer's name, so
  # names in the site table are at most 12 characters (checked below).
  interfaceOf = host: "rd-${host.name}";

  # A host's link-local address on every tunnel: fe80::<id>/64. Each tunnel
  # is its own link, so the pair is unique there.
  linkLocalOf = host: ip.address.add (ip.address.fromString 6 "fe80::/64") host.id;

  anywhere = ip.network.fromCIDR 6 "::/0";

  # Babel's multicast group: hubs send hellos to it on every tunnel.
  babelGroup = ip.address.fromString 6 "ff02::1:6";

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

        # The tunnel's interface, and both ends' link-local addresses.
        interface = interfaceOf peer;
        linkLocal = {
          self = linkLocalOf me;
          peer = linkLocalOf peer;
        };

        # What the tunnel sends to and accepts from `peer`. Towards a hub
        # anything, since routes through it lead anywhere; from a spoke only
        # what it owns, plus its link-local address and babel's group for
        # routing (devices run no babel).
        allowedIPs =
          if isHub peer
          then [anywhere]
          else
            peer.ownedNetworks
            ++ optionals (peer.kind == "nixos") [
              (ip.address.singleHostRoute (linkLocalOf peer))
              babelGroup
            ];

        # The routes babeld accepts from `peer`: from a hub, any network of
        # the site but this host's own; from a spoke, only what it owns.
        # Devices run no babel, so nothing comes from them.
        acceptedNetworks =
          if peer.kind != "nixos"
          then []
          else if isHub peer
          then
            attrValues hosts
            |> filter (host: host.name != me.name)
            |> concatMap (host: host.ownedNetworks)
          else peer.ownedNetworks;

        # Where the tunnel starts: the first endpoint this host can reach,
        # or null for a spoke (it roams; the hub learns where it is).
        endpoint = let
          reachable = candidatesFor me peer;
        in
          if isHub peer && reachable != [] && portOf peer me != null
          then endpointText (head reachable) (portOf peer me)
          else null;
      })
    (filterAttrs (_: connects) hosts);
  };

  # DEVICE TUNNELS
  # --------------
  # A device's WireGuard tunnels, one per hub and endpoint it can reach,
  # keyed `<hub>-<n>` (n counts the hub's candidates from 1, in preference
  # order). Each is { hub; endpoint; text; }, where `text` is a wg-quick file
  # with a placeholder for the private key. The device switches tunnels by
  # hand when a hub is down.
  deviceTunnels = site: name: let
    derived = derive site name;
    device = derived.self;

    # Everything the device reaches through a tunnel: every owned network
    # of the site but its own.
    siteNetworks =
      attrValues derived.hosts
      |> filter (host: host.name != name)
      |> concatMap (host: host.ownedNetworks)
      |> map ip.toCIDR;

    tunnel = hub: endpoint: let
      port =
        if hub.endpointPort == null
        then throw "radii: hub ${hub.name} has no basePort"
        else toString hub.endpointPort;

      # The wg-quick file as data; sections and keys come out sorted, which
      # WireGuard does not mind.
      config = {
        Interface = {
          PrivateKey = "<private key>";
          Address = ip.toCIDR device.hostAddress;
        };
        Peer = {
          PublicKey = hub.publicKey;
          Endpoint = endpointText endpoint port;
          AllowedIPs = concatStringsSep ", " siteNetworks;
          PersistentKeepalive = 25;
        };
      };
    in {
      hub = hub.name;
      endpoint = config.Peer.Endpoint;
      text =
        ''
          # radii: ${name} to ${hub.name} through ${hostText endpoint}.
          # Replace the placeholder with ${name}'s private key; its public key
          # is in the site table.
        ''
        + toINI {mkKeyValue = mkKeyValueDefault {} " = ";} config;
    };
  in
    if device.kind != "device"
    then throw "radii: ${name} is a ${device.kind} host; WireGuard files are generated for devices only"
    else
      attrValues derived.peers
      |> filter (peer: peer.role == "hub")
      |> concatMap (hub:
        imap1 (index: endpoint: {
          name = "${hub.name}-${toString index}";
          value = tunnel hub endpoint;
        })
        hub.candidates)
      |> listToAttrs;

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
    # Interface names allow 15 characters; "rd-" takes three.
    (hosts
      |> filter (host: builtins.match "[A-Za-z0-9_.-]{1,12}" host.name == null)
      |> map (host: "${host.name}: names must be 1 to 12 letters, digits, '_', '.' or '-' (its tunnels are named rd-${host.name})"))
    ++ duplicates "id" (host: toString host.id)
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

      # The ports this host, as a hub, needs open outside, and what its
      # openPorts says is.
      inbound = inboundPorts site self;
      needed = map (entry: entry.port) inbound;
      open = openPortsOf me;
      missing = filter (entry: !(elem entry.port open)) inbound;
      unused = filter (port: !(elem port needed)) (unique open);
      emptyRanges =
        optionals (me.openPorts != null) me.openPorts
        |> filter (entry: !(builtins.isInt entry) && entry.from > entry.to);

      showInbound = entry: "${toString entry.port} for ${entry.peer} (through ${describe entry.via})";

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
        ++ map (message: "invalid port: ${message}") invalidPorts
        ++ optional (me.role == "hub" && me.openPorts == null) (
          "hub ${self} has no openPorts: open UDP "
          + (
            if inbound == []
            then "nothing (no host can reach it)"
            else describe (map showInbound inbound)
          )
          + " at its router or provider firewall, then set openPorts = ${showPorts needed}"
        )
        ++ optional (me.role == "hub" && me.openPorts != null && missing != [])
        "hub ${self} needs UDP ${describe (map showInbound missing)} open: open them at its router or provider firewall, then set openPorts = ${showPorts needed}"
        ++ map (entry: "${self}: openPorts has an empty range, from ${toString entry.from} to ${toString entry.to}") emptyRanges;

      warnings =
        optional (me.role == "spoke" && length reachable == 1)
        "${self} reaches only one hub (${head reachable}): it has no failover"
        ++ optional (me.role == "hub" && me.openPorts != null && unused != [])
        "hub ${self}: openPorts lists UDP ${describe (map toString unused)}, which no host uses: close them at its router or provider firewall, then set openPorts = ${showPorts needed}"
        ++ optional (me.role != "hub" && me.openPorts != null)
        "${self} is not a hub: its openPorts are not used";
    };
in {
  inherit derive deviceTunnels checkSite checkHost endpointText inboundPorts;
}
