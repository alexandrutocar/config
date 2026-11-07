# Build review payload: the payload for the review webhook, from the records
# of both phases and the flake metadata of both commits. Called by
# build-review-payload.sh (nix_call in .helpers/common.sh):
#
#   nix eval --impure --json --file build-review-payload.expr.nix \
#     --apply 'f: f { artifacts = "<dir>"; branch = "ci/<ID>";
#       base = "<commit>"; commit = "<commit>"; }'
#
# Reads <dir>/{base,next}/metadata.json (nix flake metadata --json) and
# every <dir>/records/*.json. --impure is needed because they live outside
# the store. Records:
#
#   { kind = "stats"; phase; host; targets = [{ id; probe; items; }] or null; }
#   { kind = "eval"; phase; id; success; console; }
#
# with phase "base" (before the update) or "next" (after it).
#
# Payload:
#   branch     the preview branch, ci/<ID>
#   base       the commit before the update
#   commit     the update commit, on top of base
#   inputs     inputs changed by the update, each with the number of files
#              the systems use from it (`used`) and those of them that
#              changed (`changed`: file, names, status, and the files' store
#              paths `prev`/`next`, which the script replaces with a diff)
#   targets    per system / nested evaluation: eval success before (`prev`)
#              and after (`next`), console messages that appeared or
#              disappeared, and what the update added to or removed from
#              its features
#   unlocated  names in use that couldn't be traced to an input file
#
# The payload's prev/next fields are what the n8n workflow reads; they are
# unrelated to the phase names.
#
# Only builtins are used, so no nixpkgs has to be fetched.
{
  artifacts,
  branch,
  base,
  commit,
}: let
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

  chars = string: genList (i: substring i 1 string) (stringLength string);
  toLower = replaceStrings (chars "ABCDEFGHIJKLMNOPQRSTUVWXYZ") (chars "abcdefghijklmnopqrstuvwxyz");

  first = list:
    if list == []
    then null
    else head list;

  # ── Sets of strings ───────────────────────────────────────────────────

  toSet = list:
    listToAttrs (map (name: {
        inherit name;
        value = null;
      })
      list);

  # Sorted list of distinct strings.
  unique = list: attrNames (toSet list);

  # Elements of a that are (intersect) or aren't (minus) in b.
  intersect = a: b: let
    set = toSet b;
  in
    filter (x: hasAttr x set) a;
  minus = a: b: let
    set = toSet b;
  in
    filter (x: !(hasAttr x set)) a;

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

  # ── Payload fields ────────────────────────────────────────────────────

  # Drops attributes whose value is null.
  compact = attrs: removeAttrs attrs (filter (name: attrs.${name} == null) (attrNames attrs));

  # null for an empty list or set, or 0, so `compact` drops it.
  nonEmpty = x:
    if x == [] || x == {} || x == 0
    then null
    else x;

  # ── Console ───────────────────────────────────────────────────────────

  # Replaces every match of a regex.
  gsub = regex: replacement: string:
    concatStringsSep "" (map (x:
      if isList x
      then replacement
      else x) (split regex string));

  rtrim = string: let
    m = match "(.*[^[:space:]])[[:space:]]*" string;
  in
    if m == null
    then ""
    else head m;

  escape = fromJSON ''"\u001b"'';

  # Longest message kept. Longer ones (e.g. builtins.trace dumps of large
  # values) are cut, so one changed dump can't dominate the payload.
  maxMessage = 2000;

  shorten = message:
    if stringLength message > maxMessage
    then substring 0 maxMessage message + " […]"
    else message;

  # Lines unrelated to the update.
  noise = [
    "warning: Git tree .* is dirty"
    "warning: could not read HEAD ref from repo at .*"
  ];
  isNoise = line: any (regex: match regex line != null) noise;

  # Splits text before every line that doesn't start with white space.
  paragraphs = text: let
    parts = split "\n([^[:space:]])" text; # [first [char] rest [char] rest …]
  in
    [(head parts)]
    ++ genList (i: head (elemAt parts (2 * i + 1)) + elemAt parts (2 * i + 2))
    ((length parts - 1) / 2);

  # Splits console output into messages. A message starts at a line that
  # isn't indented and takes the indented or blank lines after it (error
  # traces). Colours and store path hashes are removed so the same message
  # compares equal before and after the update.
  messages = console: let
    text =
      gsub "/nix/store/[0-9a-z]{32}-" "/nix/store/"
      (gsub "${escape}\\[[0-9;]*[A-Za-z]" "" console);
    lines = filter (line: !(isNoise line)) (map rtrim (filter isString (split "\n" text)));
  in
    unique (map shorten (filter (m: m != "") (map rtrim (paragraphs (concatStringsSep "\n" lines)))));

  # ── Inputs ────────────────────────────────────────────────────────────

  repoOf = locked:
    if elem locked.type ["github" "gitlab" "sourcehut"]
    then "${locked.type}:${locked.owner}/${locked.repo}"
    else locked.url or locked.path or "unknown";

  isNixpkgs = locked: toLower (locked.owner or "") == "nixos" && toLower (locked.repo or "") == "nixpkgs";

  revisionOf = locked: {
    rev = locked.rev or null;
    utc = locked.lastModified or null;
  };

  # Locked inputs whose revision changed, or that were added, by the update.
  changedInputs = let
    lock = nextMetadata.locks;
    old = baseMetadata.locks.nodes or {};
    roots = filter isString (attrValues (lock.nodes.${lock.root}.inputs or {}));
    key = locked: locked.rev or locked.narHash or null;

    # The node's lock before the update, matched by name or else by the same
    # `original` spec (names like home-manager_2 can shift when inputs
    # change); null for an added input.
    previous = name: let
      original = lock.nodes.${name}.original or null;
      sameOriginal = filter (n: n ? locked && (n.original or null) == original) (attrValues old);
    in
      old.${name}.locked or (first sameOriginal).locked or null;

    changed = name: let
      node = lock.nodes.${name};
      was = previous name;
    in
      name != lock.root && node ? locked && (was == null || key was != key node.locked);

    describe = name: let
      node = lock.nodes.${name};
      was = previous name;
    in {
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
        else revisionOf was;
      next = revisionOf node.locked;
      # Dropped from the payload; used to fetch both revisions.
      locked = {
        prev = was;
        next = node.locked;
      };
    };
  in
    map describe (filter changed (attrNames lock.nodes));

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

  # The used files of an input ({ file = names; }) that differ between its
  # two revisions. Both revisions are fetched from their locked attributes
  # (already in the store after the evaluations). `prev`/`next` are the
  # files' store paths, which build-review-payload.sh replaces with a
  # unified diff.
  changedFiles = files: locked: let
    before = (fetchTree locked.prev).outPath;
    after = (fetchTree locked.next).outPath;

    change = file: let
      prev = resolve before file;
      next = resolve after file;
    in {
      inherit file prev next;
      names = files.${file};
      status =
        if prev == null
        then "added"
        else if next == null
        then "removed"
        else "modified";
    };

    unchanged = c:
      if c.prev == null || c.next == null
      then c.prev == c.next
      else readFile c.prev == readFile c.next;
  in
    filter (c: !(unchanged c)) (map change (attrNames files));

  # ── Records ───────────────────────────────────────────────────────────

  baseMetadata = readJSON "${artifacts}/base/metadata.json";
  nextMetadata = readJSON "${artifacts}/next/metadata.json";

  records =
    map (name: readJSON "${artifacts}/records/${name}")
    (filter (name: match ".*\\.json" name != null) (attrNames (readDir "${artifacts}/records")));

  # Targets of the stats records, each with its record's phase.
  inventories =
    concatMap (record: map (t: t // {inherit (record) phase;}) record.targets)
    (filter (r: r.kind == "stats" && r.targets != null) records);

  evals = filter (r: r.kind == "eval") records;

  items = concatMap (t: t.items) inventories;

  names = list: map (i: i.name) list;

  # ── Targets ───────────────────────────────────────────────────────────

  target = id: let
    ofPhase = phase: list: first (filter (r: r.id == id && r.phase == phase) list);

    evalBefore = ofPhase "base" evals;
    evalAfter = ofPhase "next" evals;
    messagesBefore = messages (evalBefore.console or "");
    messagesAfter = messages (evalAfter.console or "");

    inventoryBefore = ofPhase "base" inventories;
    inventoryAfter = ofPhase "next" inventories;
  in
    compact {
      inherit id;

      success =
        if evalBefore == null && evalAfter == null
        then null
        else {
          prev = evalBefore.success or null;
          next = evalAfter.success or null;
        };

      console = nonEmpty (compact {
        new = nonEmpty (minus messagesAfter messagesBefore);
        gone = nonEmpty (minus messagesBefore messagesAfter);
        unchanged = nonEmpty (length (intersect messagesAfter messagesBefore));
      });

      changes =
        if inventoryBefore == null || inventoryAfter == null
        then null
        else let
          before = collapse (names inventoryBefore.items);
          after = collapse (names inventoryAfter.items);
        in
          nonEmpty (compact {
            added = nonEmpty (minus after before);
            removed = nonEmpty (minus before after);
          });
    };

  # ── Inputs in use ─────────────────────────────────────────────────────

  # The files of an input the systems use, as { file = names; }.
  usedFiles = node:
    mapAttrs (_: group: collapse (names group))
    (groupBy (i: i.file) (filter (i: (i.node or null) == node) items));

  withFiles = input: let
    files = usedFiles input.node;
  in
    removeAttrs input ["locked"]
    // {
      used = length (attrNames files);
      changed =
        if input.locked.prev == null
        then []
        else changedFiles files input.locked;
    };
in {
  inherit branch base commit;
  inputs = map withFiles changedInputs;
  targets = map target (unique (map (r: r.id) (inventories ++ evals)));
  unlocated = collapse (names (filter (i: !(i ? node)) items));
}
