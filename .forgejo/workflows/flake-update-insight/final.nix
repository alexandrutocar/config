# ────────────────────────────────────────────────────────────────────────
# Builds the webhook payload from the records collected by
# flake-update-insight.sh.
#
#   nix eval --impure --json --file final.nix \
#     --apply 'final: final { workDir = "<dir>"; }'
#
# Reads <dir>/{prev,next}/metadata.json (nix flake metadata --json),
# <dir>/run.json ({ branch; base; fresh; }, optional) and every
# <dir>/records/*.json. --impure is needed because they live outside the
# store. Records:
#
#   { kind = "stats"; phase; host; targets = [{ id; probe; items; }] or null; }
#   { kind = "eval"; phase; id; success; console; }
#
# Payload:
#   branch     the insight branch
#   base       the commit before the update (previous branch tip, or the
#              merge of the main branch into it)
#   commit     the update commit, on top of base
#   fresh      true when the branch started anew from the main branch
#              (first run after the PR was merged): a new PR, not an update
#   inputs     inputs changed by the update, each with the number of files
#              this configuration uses from it (`used`) and those of them
#              that changed (`changed`: file, names, status, and the files'
#              store paths, replaced by a diff in flake-update-insight.sh)
#   targets    per host / nested evaluation: eval success before and after,
#              console messages that appeared or disappeared, and what the
#              update added to or removed from its stats
#   unlocated  names in use that couldn't be traced to an input file
#
# Only builtins are used, so no nixpkgs has to be fetched.
# ────────────────────────────────────────────────────────────────────────
{workDir}: let
  inherit
    (builtins)
    any
    attrNames
    attrValues
    concatMap
    concatStringsSep
    elem
    elemAt
    fetchTree
    filter
    foldl'
    fromJSON
    genList
    groupBy
    hasAttr
    head
    isList
    isString
    length
    listToAttrs
    mapAttrs
    match
    pathExists
    readDir
    readFile
    readFileType
    removeAttrs
    replaceStrings
    split
    stringLength
    substring
    ;

  # ── Helpers ───────────────────────────────────────────────────────────

  readJSON = path: fromJSON (readFile path);

  hasSuffix = suffix: string: let
    n = stringLength string;
    k = stringLength suffix;
  in
    n >= k && substring (n - k) k string == suffix;

  chars = string: genList (i: substring i 1 string) (stringLength string);
  toLower = replaceStrings (chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ") (chars "abcdefghijklmnopqrstuvwxyz");

  last = list: elemAt list (length list - 1);
  init = list: genList (elemAt list) (length list - 1);
  first = list:
    if list == []
    then null
    else head list;

  toSet = list:
    listToAttrs (map (name: {
        inherit name;
        value = null;
      })
      list);

  # Sorted list of distinct strings.
  unique = list: attrNames (toSet list);

  # Elements of a that aren't in b (strings).
  minus = a: b: let
    set = toSet b;
  in
    filter (x: !(hasAttr x set)) a;

  # Drops attributes whose value is null.
  compact = attrs: removeAttrs attrs (filter (name: attrs.${name} == null) (attrNames attrs));

  nonEmpty = x:
    if x == [] || x == {}
    then null
    else x;

  # Replaces every match of a regex.
  gsub = regex: replacement: string:
    concatStringsSep "" (map (x:
      if isList x
      then replacement
      else x) (split regex string));

  rtrim = line: let
    m = match "(.*[^[:space:]])[[:space:]]*" line;
  in
    if m == null
    then ""
    else head m;

  # Drops names covered by a shorter one ("services.openssh.enable" by
  # "services.openssh"), and sorts and deduplicates them.
  collapse = names: let
    all = unique names;
    set = toSet all;
    covered = name: let
      parts = filter isString (split "\\." name);
      prefix = n: concatStringsSep "." (genList (elemAt parts) n);
    in
      any (n: hasAttr (prefix n) set) (genList (i: i + 1) (length parts - 1));
  in
    filter (name: !(covered name)) all;

  # ── Console ───────────────────────────────────────────────────────────

  escape = fromJSON ''"\u001b"'';

  # Longest message kept. Longer ones (e.g. builtins.trace dumps of large
  # values) are cut, so one changed dump can't dominate the payload.
  maxMessage = 2000;

  shorten = message:
    if stringLength message > maxMessage
    then substring 0 maxMessage message + " […]"
    else message;

  # Splits console output into messages. A message starts at a line that
  # isn't indented and takes the indented or blank lines after it (error
  # traces). Colours and store path hashes are removed so the same message
  # compares equal before and after the update.
  messages = console: let
    text =
      gsub "/nix/store/[0-9a-z]{32}-" "/nix/store/"
      (gsub "${escape}\\[[0-9;]*[A-Za-z]" "" console);
    # Noise from evaluating a detached worktree, unrelated to the update.
    noise = line:
      match "warning: Git tree .* is dirty" line
      != null
      || match "warning: could not read HEAD ref from repo at .*" line != null;
    lines = filter (line: !(noise line)) (map rtrim (filter isString (split "\n" text)));
    continues = line: line == "" || match "[[:space:]].*" line != null;
    groups = foldl' (acc: line:
      if acc != [] && continues line
      then init acc ++ [(last acc ++ [line])]
      else acc ++ [[line]]) []
    lines;
    dropTrailing = group:
      if group != [] && last group == ""
      then dropTrailing (init group)
      else group;
  in
    unique (map shorten (filter (m: m != "") (map (group: concatStringsSep "\n" (dropTrailing group)) groups)));

  # ── Inputs ────────────────────────────────────────────────────────────

  repoOf = locked:
    if locked.type == "github"
    then "github:${locked.owner}/${locked.repo}"
    else if locked.type == "gitlab"
    then "gitlab:${locked.owner}/${locked.repo}"
    else if locked.type == "sourcehut"
    then "sourcehut:${locked.owner}/${locked.repo}"
    else locked.url or locked.path or "unknown";

  isNixpkgs = locked: toLower (locked.owner or "") == "nixos" && toLower (locked.repo or "") == "nixpkgs";

  # Locked inputs whose revision changed, or that were added, by the update.
  # Nodes are matched by name, falling back to the same `original` spec
  # (names like home-manager_2 can shift when inputs change).
  changedInputs = let
    lock = next.locks;
    old = prev.locks.nodes or {};
    roots = filter isString (attrValues (lock.nodes.${lock.root}.inputs or {}));
    key = locked: locked.rev or locked.narHash or null;

    previous = name: node: let
      byOriginal = first (filter (n: n ? locked && (n.original or null) == (node.original or null)) (attrValues old));
    in
      old.${name}.locked or byOriginal.locked or null;

    entry = name: let
      node = lock.nodes.${name};
      was = previous name node;
    in
      if name == lock.root || !(node ? locked) || (was != null && key was == key node.locked)
      then null
      else {
        node = name;
        repo = repoOf node.locked;
        ref = node.original.ref or null;
        group =
          if !(elem name roots)
          then "transient"
          else if isNixpkgs node.locked
          then "nixpkgs"
          else "direct";
        prev =
          if was == null
          then null
          else {
            rev = was.rev or null;
            utc = was.lastModified or null;
          };
        next = {
          rev = node.locked.rev or null;
          utc = node.locked.lastModified or null;
        };
        # Dropped from the payload; used to fetch both revisions.
        locked = {
          prev = was;
          next = node.locked;
        };
      };
  in
    filter (e: e != null) (map entry (attrNames lock.nodes));

  # ── Changed files ─────────────────────────────────────────────────────

  # Path of a file inside a source, or null when it doesn't exist there. A
  # directory (a module imported as a folder) stands for its default.nix.
  resolve = source: file: let
    path = "${source}/${file}";
  in
    if !(pathExists path)
    then null
    else if readFileType path == "directory"
    then resolve source "${file}/default.nix"
    else path;

  # The used files of an input that differ between its two revisions. Both
  # revisions are fetched from their locked attributes (already in the store
  # after the evaluations). `prev`/`next` are the files' store paths, which
  # flake-update-insight.sh replaces with a unified diff.
  changedFiles = files: locked: let
    before = (fetchTree locked.prev).outPath;
    after = (fetchTree locked.next).outPath;
    compare = file: let
      a = resolve before file;
      b = resolve after file;
    in
      if (a == null && b == null) || (a != null && b != null && readFile a == readFile b)
      then []
      else [
        {
          inherit file;
          names = files.${file};
          status =
            if a == null
            then "added"
            else if b == null
            then "removed"
            else "modified";
          prev = a;
          next = b;
        }
      ];
  in
    concatMap compare (attrNames files);

  # ── Records ───────────────────────────────────────────────────────────

  prev = readJSON "${workDir}/prev/metadata.json";
  next = readJSON "${workDir}/next/metadata.json";

  records =
    map (name: readJSON "${workDir}/records/${name}")
    (filter (hasSuffix ".json") (attrNames (readDir "${workDir}/records")));

  inventories =
    concatMap (record: map (t: t // {inherit (record) phase;}) (record.targets or []))
    (filter (r: r.kind == "stats" && r.targets != null) records);

  evals = filter (r: r.kind == "eval") records;

  items = concatMap (t: t.items) inventories;

  ofPhase = phase: list: first (filter (r: r.phase == phase) list);

  names = list: map (i: i.name) list;

  # ── Targets ───────────────────────────────────────────────────────────

  target = id: let
    inventory = filter (t: t.id == id) inventories;
    eval = filter (r: r.id == id) evals;

    pe = ofPhase "prev" eval;
    ne = ofPhase "next" eval;
    pm = messages (pe.console or "");
    nm = messages (ne.console or "");
    unchanged = length (minus nm (minus nm pm));

    pi = ofPhase "prev" inventory;
    ni = ofPhase "next" inventory;
  in
    compact {
      inherit id;

      success =
        if pe == null && ne == null
        then null
        else {
          prev = pe.success or null;
          next = ne.success or null;
        };

      console = nonEmpty (compact {
        new = nonEmpty (minus nm pm);
        gone = nonEmpty (minus pm nm);
        unchanged =
          if unchanged == 0
          then null
          else unchanged;
      });

      changes =
        if pi == null || ni == null
        then null
        else let
          before = collapse (names pi.items);
          after = collapse (names ni.items);
        in
          nonEmpty (compact {
            added = nonEmpty (minus after before);
            removed = nonEmpty (minus before after);
          });
    };
  run =
    if pathExists "${workDir}/run.json"
    then readJSON "${workDir}/run.json"
    else {};
in
  run
  // {
    commit = next.revision or null;

    inputs = map (input: let
      files =
        mapAttrs (_: group: collapse (names group))
        (groupBy (i: i.file) (filter (i: (i.node or null) == input.node) items));
    in
      removeAttrs input ["locked"]
      // {
        used = length (attrNames files);
        changed =
          if input.locked.prev == null
          then []
          else changedFiles files input.locked;
      })
    changedInputs;

    targets = map target (unique (map (r: r.id) (inventories ++ evals)));

    unlocated = collapse (names (filter (i: !(i ? node)) items));
  }
