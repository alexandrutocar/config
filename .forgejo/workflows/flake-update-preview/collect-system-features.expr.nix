# Collect system features: what one system and every nested NixOS
# evaluation inside it (see `subEvaluations`) use, called by
# collect-system-features.sh for the base and the update commit
# (nix_call in .helpers/common.sh):
#
#   nix eval --impure --json --file collect-system-features.expr.nix \
#     --apply 'f: f {
#       flake = builtins.getFlake "...";  # the flake at the commit
#       host = "<system>";                # nixosConfigurations name
#       part = "core";                    # or "options"
#       target = "<id>";                  # optional
#     }'
#
# Returns one target for the system itself and one for every nested
# evaluation: { id; probe; items; }. `probe` is the attribute path, below
# nixosConfigurations.<system>, whose drvPath evaluate-system-closure.sh
# evaluates (null without a toplevel). `items` lists what the target uses,
# mapped to the flake input (lock node) and the file in that input which
# provides it:
#
#   - packages: environment.systemPackages, home.packages and the
#     `package` option of every enabled module (file from meta.position),
#   - enabled modules: services.* and programs.* with `enable = true`,
#   - options set by this repository (file from the option declaration,
#     the "Declared in" location shown on search.nixos.org).
#
# `part` selects what is collected, so the script can run the two in
# separate processes (an uncatchable error in one doesn't lose the other):
#
#   core     packages and enabled modules (cheap, rarely fails)
#   options  options set by this repository (walks every option)
#
# `target` (an id from the core part, e.g. "beidou/sigil/web/1234") limits
# the result to one target, so the script can run the options part once per
# target and a failing container doesn't lose the system's options.
#
# Things declared in this repository are left out. Items whose file can't
# be traced to any file (packages without meta.position) are returned with
# just their name.
{
  flake,
  host,
  part ? "core",
  target ? null,
}:
assert builtins.elem part ["core" "options"]; let
  system = flake.nixosConfigurations.${host};
  lib = system.lib or system.pkgs.lib;

  inherit (builtins) attrNames concatMap concatStringsSep deepSeq elemAt filter hasAttr head isAttrs match tryEval;

  # x, or default when evaluating it (to weak head normal form, or fully for
  # tryDeepOr) throws. Missing attributes, type errors and aborts can't be
  # caught by Nix; they fail the whole part (see `part` above).
  tryOr = default: x: let
    r = tryEval x;
  in
    if r.success
    then r.value
    else default;
  tryDeepOr = default: x: tryOr default (deepSeq x x);

  isOption = o: isAttrs o && (o._type or null) == "option";

  # Renamed and removed options are declared invisible. Reading them prints
  # "Obsolete option" traces and some abort evaluation, so they are skipped.
  isVisible = o: (o.visible or true) != false;

  # ── Sources ───────────────────────────────────────────────────────────
  # Maps the store path of every input (three levels deep) to its lock node.

  storePath = p: builtins.unsafeDiscardStringContext (toString p);

  lock = builtins.fromJSON (builtins.readFile "${flake.outPath}/flake.lock");

  nodeByNarHash = builtins.listToAttrs (concatMap (name: let
    locked = lock.nodes.${name}.locked or {};
  in
    lib.optional (locked ? narHash) (lib.nameValuePair locked.narHash name))
  (attrNames lock.nodes));

  inputsOf = depth: inputs:
    concatMap (name: let
      input = inputs.${name};
    in
      tryDeepOr [] [
        {
          path = storePath input.outPath;
          narHash = input.narHash or null;
        }
      ]
      ++ lib.optionals (depth > 0) (tryDeepOr [] (inputsOf (depth - 1) (input.inputs or {}))))
    (attrNames inputs);

  sources = builtins.listToAttrs (concatMap (input:
    lib.optional (input.narHash != null && hasAttr input.narHash nodeByNarHash)
    (lib.nameValuePair input.path nodeByNarHash.${input.narHash}))
  (inputsOf 3 flake.inputs));

  # { node, file } for a file inside an input, "self" for anything else in
  # the store, null for files outside it (e.g. <unknown-file>) and for no
  # file at all.
  #
  # Store paths that aren't an input count as this repository: besides the
  # flake source itself, configurations copy parts of it to the store under
  # their own names (e.g. …-_config, …-modules via builtins.path).
  #
  # A root flake.nix is no real location: modules passed as values
  # (inputs.x.nixosModules.y) have no file of their own, and the module
  # system reports the flake.nix that passed them (e.g. nixpkgs' for
  # nixosSystem). Those items count as unlocated. Import such modules by path
  # ("${inputs.x}/module.nix") to have them located.
  locate = file: let
    m = match "(/nix/store/[^/]+)/(.*)" (storePath file);
  in
    if m == null
    then null
    else if !(hasAttr (head m) sources)
    then "self"
    else if elemAt m 1 == "flake.nix"
    then null
    else {
      node = sources.${head m};
      file = elemAt m 1;
    };

  # An item named `name` at its file's location; null for this repository.
  item = name: file: let
    location = locate file;
  in
    if location == "self"
    then null
    else lib.optionalAttrs (isAttrs location) location // {inherit name;};

  # ── Packages ──────────────────────────────────────────────────────────

  # { name, file } of a package, with the line number cut from meta.position.
  packageInfo = package: let
    position = package.meta.position or null;
    m = match "(.*):[0-9]+" (toString position);
  in {
    name = package.pname or (builtins.parseDrvName package.name).name;
    file =
      if m == null
      then position
      else head m;
  };

  packageItem = package: let
    info = tryDeepOr null (
      if lib.isDerivation package
      then packageInfo package
      else null
    );
  in
    if info == null
    then null
    else item "pkgs.${info.name}" info.file;

  # ── Modules ───────────────────────────────────────────────────────────

  # Names below a namespace (services, programs) whose real `enable` is true.
  enabledIn = opts: cfg:
    filter (n:
      tryOr false (let
        o = opts.${n};
      in
        isAttrs o
        && !(isOption o) # a whole renamed namespace, e.g. services.bitwarden_rs
        && isOption (o.enable or null)
        && isVisible o.enable
        && (cfg.${n}.enable or false) == true))
    (attrNames opts);

  moduleItems = prefix: opts: cfg:
    concatMap (n: let
      o = opts.${n};
      package = tryOr null (
        if isOption (o.package or null) && isVisible o.package
        then cfg.${n}.package
        else null
      );
    in
      map (item "${prefix}.${n}") (o.enable.declarations or [])
      ++ lib.optional (package != null) (packageItem package))
    (enabledIn opts cfg);

  # ── Options set by this repository ────────────────────────────────────

  # Every visible, non-internal option below a set, as { path, option }.
  #
  # Internal options are module plumbing rather than settings a configuration
  # makes, and their definitions can't always be evaluated where they aren't
  # used: e.g. systemd.nix defines system.requiredKernelConfig from
  # config.lib.kernelConfig, which only exists with boot.kernel.enable, so
  # reading it in a container evaluation fails with a missing attribute.
  optionsIn = prefix: set:
    concatMap (n:
      tryOr [] (let
        v = set.${n};
      in
        if lib.hasPrefix "_" n
        then []
        else if isOption v
        then
          lib.optional (isVisible v && !(v.internal or false)) {
            path = prefix ++ [n];
            option = v;
          }
        else if isAttrs v
        then optionsIn (prefix ++ [n]) v
        else []))
    (attrNames set);

  # True when a definition comes from this repository (or an unknown file),
  # i.e. from no input.
  #
  # Options that only have their default (highestPrio 1500, mkOptionDefault)
  # or nothing at all (9999) are skipped before `files` is read: reading
  # `files` evaluates the default, and defaults of disabled modules can fail
  # in ways tryEval can't catch, e.g. services.dawarich's default reading
  # services.redis.servers.dawarich, or hardware.nvidia.open's reading the
  # nvidia package on hosts without one. highestPrio itself doesn't touch the
  # default. Without highestPrio (very old nixpkgs) nothing is collected.
  definedHere = option:
    tryOr false (
      (option.highestPrio or 9999)
      < 1500
      && builtins.any (file: !(isAttrs (locate file))) (option.files or [])
    );

  definedItems = prefix: options:
    concatMap (o: map (item (prefix + concatStringsSep "." o.path)) (o.option.declarations or []))
    # meta.* (maintainers, docs) is documentation, not configuration.
    (filter (o: head o.path != "meta" && definedHere o.option) (optionsIn [] options));

  # ── Evaluations ───────────────────────────────────────────────────────

  # Everything a NixOS evaluation ({ config, options? }) uses, as items.
  # Each section is evaluated on its own so one failure doesn't empty the rest.
  describe = evaluation: let
    inherit (evaluation) config;
    options = evaluation.options or null;
    users = config.home-manager.users or {};

    # Home Manager option declarations (shared by all users), used when the
    # per-user evaluation isn't exposed.
    hmDeclared =
      if options == null
      then {}
      else tryOr {} (options.home-manager.users.type.getSubOptions []);

    # Per-user options via valueMeta (nixpkgs with valueMeta support only).
    hmOwn = name: let
      meta = options.home-manager.users.valueMeta.attrs.${name} or null;
    in
      meta.configuration.options or meta.options or null;

    user = name: let
      cfg = users.${name};
      own = hmOwn name;
      opts =
        if own != null
        then own
        else hmDeclared;
    in
      if part == "options"
      then lib.optional (own != null) (definedItems "hm." own)
      else [
        (map packageItem (cfg.home.packages or []))
        (moduleItems "hm.programs" (opts.programs or {}) (cfg.programs or {}))
        (moduleItems "hm.services" (opts.services or {}) (cfg.services or {}))
      ];

    sections =
      (
        if part == "options"
        then lib.optional (options != null) (definedItems "" options)
        else
          [(map packageItem (config.environment.systemPackages or []))]
          ++ lib.optionals (options != null) [
            (moduleItems "services" (options.services or {}) (config.services or {}))
            (moduleItems "programs" (options.programs or {}) (config.programs or {}))
          ]
      )
      ++ concatMap user (attrNames users);
  in
    filter (i: i != null) (concatMap (tryDeepOr []) sections);

  # Nested NixOS evaluations inside the host, as { id, path } relative to the
  # host. Add other kinds here (e.g. containers with an exposed evaluation).
  subEvaluations = let
    containers = ["config" "services" "sigil" "settings" "containers"];
    groups = lib.attrByPath containers {} system;
  in
    concatMap (group:
      map (uuid: {
        id = "${host}/sigil/${group}/${uuid}";
        path = containers ++ [group uuid "evaluation"];
      }) (attrNames groups.${group}))
    (attrNames groups);

  # Attribute path (relative to nixosConfigurations.<host>) whose drvPath is
  # evaluated by evaluate-system-closure.sh, or null when the evaluation has
  # no toplevel.
  probeOf = path: evaluation:
    if tryOr false ((evaluation.config.system.build or {}) ? toplevel)
    then path ++ ["config" "system" "build" "toplevel"]
    else null;

  mkTarget = id: path: evaluation: let
    valid = isAttrs evaluation && evaluation ? config;
  in {
    inherit id;
    probe =
      if valid
      then probeOf path evaluation
      else null;
    items =
      if valid
      then describe evaluation
      else [];
  };

  targets =
    [(mkTarget host [] system)]
    ++ map (sub: mkTarget sub.id sub.path (lib.attrByPath sub.path null system)) (tryDeepOr [] subEvaluations);
in
  # With `target`, only that target is described; the others are filtered
  # by id before their items are evaluated.
  filter (t: target == null || t.id == target) targets
