# `services.sigil` — Developer Documentation

> [!WARN] This documentation file is fully AI-generated.

Declarative `systemd-nspawn` containers with **content-derived IPv6 addressing** and
**point-to-point L2 bridges** between containers.

The module has two halves:

| Half | Location in file | Job |
| --- | --- | --- |
| **Options** | `options.services.sigil` | Define containers/links, derive identity + addresses, and *evaluate each container's own NixOS system* |
| **Config** | `config` (`mkIf cfg.enable`) | Emit host-side units: `systemd.nspawn`, service drop-ins, tmpfiles, `systemd-networkd` netdevs/networks |

Nothing here uses `containers.<name>` from nixpkgs. Sigil drives `systemd-nspawn@.service`
directly and builds each guest with its own `eval-config.nix` call.

---

## 1. Vocabulary

| Term | Meaning |
| --- | --- |
| **MID** | *Machine ID*. The container's identity. **Must be a UUID** — it is passed verbatim to `systemd-nspawn --uuid=` and `--machine=`, and it seeds the interface identifier. |
| **Group** (a.k.a. *zone*) | The outer attribute in `settings.containers.<group>.<mid>`. Determines which ULA `/64` the container lives in. |
| **IID** | *Interface identifier*. The low 64 bits of an address, derived from the MID. |
| **GUA** | Globally routable address. One flat `/64` shared by all containers. |
| **ULA** | Site-local address. One `/64` per group, carved out of a host-managed `/48`. |
| **Link** | A declared adjacency between two containers. Declared under `settings.network.links.<group>.<source-mid>`. |
| **BID** | *Bridge ID*. Direction-free — `a→b` and `b→a` hash to the same BID, therefore the same bridge. |
| **PID** | *Policy ID*. Directional — `a→b` and `b→a` differ. Reserved for per-direction firewall/policy rules. |
| **Policy** | A single link record *as declared* (has a direction). |
| **Bridge** | The deduplicated (by BID) L2 domain joining the two endpoints of one or more policies. |

---

## 2. Option tree

```
services.sigil
├── enable
└── settings
    ├── containers.<group>.<mid>
    │   ├── mid            str      (default: attribute name)
    │   ├── group          str      (default: enclosing attribute name)
    │   ├── addresses.gua  nullOr str  (derived; overridable, null = no GUA)
    │   ├── addresses.ula  nullOr str  (derived; overridable, null = no ULA)
    │   ├── nspawn.config  systemd.nspawn.<name> submodule
    │   ├── nspawn.flags   listOf str   (CLI flags for systemd-nspawn)
    │   ├── modules        listOf deferredModule  ← your guest NixOS config
    │   └── evaluation     readOnly     ← the evaluated guest system
    └── network
        ├── links.<group>.<source-mid> = [ { target = <container>; } … ]
        │   └── each element also exposes readOnly: source, bid, pid
        ├── gua.prefix     str   a /64
        ├── ula.prefix     str   a /48
        └── ula.source     str   PreferredSource= for host→container ULA routes
```

### How `group` is threaded in

`containers` is not a plain `attrsOf (attrsOf submodule)`. The outer level is a submodule
whose `freeformType` is built *from its own `name`*:

```nix
attrsOf (submodule ({ name, ... }: {
  freeformType = attrsOf (containerModule name);   # name == the group
}))
```

That closure is the only reason `group` and the ULA prefix can default correctly without
the user restating them. Two consequences:

* **Any** attribute under a group becomes a container — a typo silently creates one.
* `containerModule` is a *function* `group -> submodule`, not a submodule.

The same trick is used for links, but via a custom option type (`linksList`) whose `merge`
reads the option path to recover `group` and `source`:

```nix
merge = loc: defs: let n = length loc;
  source = elemAt loc (n - 1);   # settings.network.links.<group>.<source>
  group  = elemAt loc (n - 2);
in (listOf (linkModule group source)).merge loc defs;
```

`getSubOptions` substitutes the placeholders `<group>` / `<source>` so option docs still render.

### Containers stringify to their MID

```nix
apply = mapAttrs (_: mapAttrs (_: c: c // { __toString = self: self.mid; }));
```

So `"${config.services.sigil.settings.containers.intra."fd0c…"}"` yields the MID. Several
places in the `config` section rely on this (e.g. `systemd.targets.machines.wants`).

---

## 3. Usage

A complete host-side declaration of one container with two links and an encrypted credential:

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.files.list) recursive;
  inherit (lib.modules) mkAfter;
in let
  mid = "e079b57e-4727-4408-8c33-39abaae975d9";
in {
  services = {
    sigil = {
      settings = {
        containers = {
          intra = {
            ${mid} = {
              modules = recursive ./_config;
              nspawn = {
                flags = mkAfter [
                  "--load-credential=credential.secret:%d/credential.secret"
                ];
              };
            };
          };
        };

        network = {
          links = {
            intra = {
              ${mid} = [
                {
                  target = config.services.sigil.settings.containers.intra.a8e714de-f158-49fc-958a-9176f25d2973; # intra/collaboration/dav
                }
                {
                  target = config.services.sigil.settings.containers.intra.c38a828e-58a7-49af-894d-ba02f936d211; # intra/operation/auth
                }
              ];
            };
          };
        };
      };
    };
  };

  systemd.services."systemd-nspawn@${mid}" = {
    serviceConfig = {
      LoadCredentialEncrypted = [
        # { xxd -r -p <<< "$(systemd-id128 show "e079b57e472744088c3339abaae975d9" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
        "credential.secret:${./_secret/credential.secret.encrypted}"
      ];
    };
  };
}
```

### 3.1 What is *not* written here

No addresses, no interface names, no bridge definitions. `group` defaults to `intra`, `mid`
defaults to the attribute name, and everything in §4 falls out of those two. Adding a link
adds a bridge, two veth pairs and four networkd units — none of which appear above.

### 3.2 Structural notes

**Bind the MID once.** It appears three times — container key, link key, unit name — and a
drift between them fails in three different, unhelpful ways. The `let mid = …` binding is
not stylistic.

**Bare UUID attributes.** `containers.intra.a8e714de-…` parses unquoted because Nix
identifiers are `[a-zA-Z_][a-zA-Z0-9_'-]*` — hyphens and digits are legal, but **not as the
first character**. A MID starting with a digit must be written `."0f3c…"`. Using `${mid}`
sidesteps the question.

**Annotate targets.** MIDs carry no meaning; the `# intra/collaboration/dav` trailing
comments are the only thing making the link list readable. Treat this as required.

**Declare each adjacency once.** BIDs are direction-free (§4), so the bridge is identical no
matter which endpoint declares the link. The peer still sees it — `linksFor` folds
`policies.incoming` into its `bridge` view (§5). Declaring both directions is not an error,
it just produces a second *policy* over the same bridge; do it only when you actually want
per-direction policy.

**Both endpoints must exist** in `settings.containers` within the same host evaluation.
`target` is dereferenced directly, so a bad UUID is an attribute-missing error at eval time.

### 3.3 Reaching past the sigil options

`nspawn.flags` uses `mkAfter` so the entry lands after the module's `mkBefore` base flags
(`--settings=trusted`, `--uuid=`, …). `%d` is systemd's credentials-directory specifier; the
module joins flags with `concatStringsSep " "` into `ExecStart` verbatim, so specifiers
survive to runtime expansion.

The trailing `systemd.services."systemd-nspawn@${mid}"` block is the general escape hatch.
The module already declares that unit with `overrideStrategy = "asDropin"`; a second
definition merges into the same drop-in through ordinary NixOS module merging. Anything the
sigil options do not expose can be set this way.

### 3.4 The credential chain

Four hops, two independent key hierarchies:

```
./_secret/credential.secret.encrypted        sealed to host key + TPM2
  └─ LoadCredentialEncrypted (host unit)  →  %d/credential.secret
       └─ --load-credential=…             →  guest credential "credential.secret"
            └─ _container/config/01-administration/02-credentials/credential.secret.nix
```

The comment above the path regenerates the blob:

| Fragment | Effect |
| --- | --- |
| `systemd-id128 show "<mid, dashes stripped>" --app-specific=d3acecba-… --value` | Derives a 128-bit ID from the MID under a fixed application namespace; prints hex. |
| `xxd -r -p` | Hex → the 16 raw bytes. |
| `head -c 4096 /dev/urandom` | Appends fresh entropy. |
| `systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -` | Seals the 4112-byte blob, stdin → stdout. |

The first 16 bytes are therefore a reproducible function of the MID; the rest is one-time
entropy. `--name=` is authenticated and **must** match the credential id in
`LoadCredentialEncrypted`, or decryption fails at start.

Two failure modes follow from the split:

* **Host reprovisioned / TPM reset** → the `.encrypted` file no longer decrypts. Regenerate it.
* **MID changed** → anything the *guest* encrypted with `systemd-creds` (which keys off the
  guest machine-id, i.e. the MID) is **deleted without warning** on the next decryption
  attempt. This is the hazard the module's `--uuid=` comment warns about; see §6.1.

### 3.5 Checklist for a new container

1. Pick a UUID (`systemd-id128 new -u`) and bind it to `mid`.
2. Add `containers.<group>.${mid}` with `modules = recursive ./_config`.
3. Add `network.links.<group>.${mid}` entries for peers it must reach, annotated.
4. If it needs credentials, add the encrypted blob plus the `--load-credential` flag.
5. Nothing else. Addresses, bridges and units are derived.

---

## 4. Identity and address derivation

All identifiers are **pure functions of names** — no state, no allocator, no registry.

```
IID(mid)          = sha256(mid)[0:16] grouped 4:4:4:4      →  "a1b2:c3d4:e5f6:0718"
GUA(mid)          = gua.prefix ":" IID(mid)
ULAprefix(group)  = ula.prefix ":" sha256(group)[0:4]      →  the per-group /64 subnet id
ULA(group,mid)    = ULAprefix(group) ":" IID(mid)

BID(a,b)          = sha256( join(":", sort([a,b])) )[0:12]     direction-free
PID(a,b)          = sha256( a ":" b )[0:12]                    directional
```

Interface names:

```
bridge            br-<BID>                            3 + 12 = 15 chars
host side of link lh-<sha256(BID + MID)[0:12]>        3 + 12 = 15 chars
guest side        lc-<sha256(BID + MID)[0:12]>        3 + 12 = 15 chars
```

15 characters is the Linux `IFNAMSIZ` limit (16 including NUL). **Do not widen these
substrings without shortening the prefixes.** The BID-collision assertion exists precisely
because 48 bits is the budget after that constraint.

`mkBridgeName`, `mkLHLinkName`, `mkLCLinkName` are defined in the top-level `let` — outside
`options` and `config` — because both halves need them.

---

## 5. Guest evaluation

Each container's `evaluation` option calls `nixos/lib/eval-config.nix` **once**, lazily:

```nix
prefix     = [ "sigil" "containers" <group> <mid> ];   # good error messages
system     = null;                                     # pkgs comes from the host
modules    = config.modules                            # user-supplied
          ++ recursive ./_container                    # the static guest baseline
          ++ [ read-only.nix, self + /nix/nixos,
               { nixpkgs.pkgs = pkgs; system.stateVersion = "26.05"; } ];
specialArgs = { inherit lib; sigil = { self = …; containers = …; }; };
```

* `read-only.nix` + `nixpkgs.pkgs = pkgs` means the guest **shares the host's nixpkgs
  instance** — no second evaluation of nixpkgs, no cross-compilation machinery.
* `recursive ./_container` (from `lib.extra.files.list`) globs every `.nix` file under the
  `_container` tree. Adding a file there is enough to add it to every container.
* The result is consumed as `container.evaluation.config.system.build.toplevel`.

### The `sigil` specialArg

Guest modules receive `sigil`, an address book:

```nix
sigil.self                  # infosFor <this container>
sigil.containers.<group>.<mid>   # infosFor <any container>

infosFor c = {
  inherit (c) mid group addresses;
  links = {
    lib.bridge.mapToAttrs  f;   # f :: { bid, port } -> attrset   (merged)
    lib.bridge.mapToList   f;   # f :: { bid, port } -> list      (concatenated)
    lib.policy.mapToAttrs  f;   # f :: <link> -> attrset
    lib.policy.mapToList   f;   # f :: <link> -> list
  };
}
```

Note the asymmetry, and it is deliberate:

* **`policy`** iterates only *outgoing* links (`links.<group>.<mid>`), because direction
  matters for policy.
* **`bridge`** iterates the deduplicated union of *outgoing and incoming* links, and each
  entry carries `port` = **the other endpoint**. Interface configuration is symmetric, so a
  guest must see a bridge whether it declared the link or was named as a target.

`policies.incoming` is computed by scanning every group/source in
`cfg.settings.network.links` for entries whose `target.mid` matches. It is O(all links) per
container; fine at this scale, worth knowing if the link count grows.

---

## 6. What the host emits

### 6.1 Per container

**Service drop-in** — `systemd.services."systemd-nspawn@<mid>"`:

* `overrideStrategy = "asDropin"` — extends the stock template rather than replacing it.
* `restartTriggers` on the JSON of the guest `toplevel` **and** of the generated
  `systemd.nspawn.<mid>` unit, so `nixos-rebuild switch` restarts containers whose guest
  config or nspawn settings changed.
* `ExecStart` is reset (`""`) and rebuilt as `systemd-nspawn <flags…>`.
* `systemd.targets.machines.wants` pulls each service in.

**Flags** (`mkBefore`, so user additions land after):

```
--settings=trusted   honour the full .nspawn file, including networking
--keep-unit          nspawn is already inside its own unit
--quiet
--uuid=<mid>         ← stable machine-id
--machine=<mid>
```

> The inline comment is a load-bearing warning: host-key-based `systemd-creds` ties
> `credential.secret` to the machine ID. If the machine ID changes, the secret is **deleted
> without warning** on the next decryption attempt. Hence UUID-typed MIDs and the assertion
> enforcing them.

**tmpfiles** — creates `/var/lib/machines/<mid>/usr` owned by `524288:524288`, the base of
the UID range `PrivateUsers=pick` allocates from.

**`systemd.nspawn.<mid>`** — merged with the user's `nspawn.config`:

```
PrivateUsers=pick              PrivateUsersOwnership=chown
Ephemeral=true                 ← guest root is volatile
Boot=false, Parameters=<toplevel>/init
LinkJournal=try-host           Timezone=off
KillSignal=SIGRTMIN+3          ← systemd's shutdown signal
BindReadOnly=/nix/store:/nix/store:idmap
Private=true, VirtualEthernet=true
```

**Host veth network** — `systemd.network.networks."10-ve-<mid>"`:

```
Match: Name=ve-<mid>, Kind=veth
IPv6LinkLocalAddressGenerationMode = none
Address = fe80::1/64                      ← host side, fixed
Route → <GUA>/128 via fe80::c onlink
Route → <ULA>/128 via fe80::c onlink, PreferredSource = ula.source
```

Two contracts follow from this, and the guest side must uphold them (see `_container/config/02-network/01-interfaces/01-host`):

1. The guest's host-facing interface **must** carry `fe80::c`.
2. The guest addresses itself with its own GUA/ULA; the host installs only `/128` host routes.

`IPv6Forwarding = true` is set globally so the host can route between them.

> `ve-<mid>` is a 39-character name — far over `IFNAMSIZ`. `systemd-nspawn` truncates the real
> ifname and sets the full name as an **altname**; the `Name=` match resolves through the
> altname. The helper is literally called `systemd-nspawn.ve.altname` for this reason.

### 6.2 Per link

Emitted only when `settings.network.links != {}`.

1. **Guest interfaces.** For every `(bridge, port)` pair, append to that container's
   `networkConfig.VirtualEthernetExtra`:

   ```
   lh-<hash>:lc-<hash>          # host-side name : guest-side name
   ```

   The `foldl'` groups entries by MID so a container with several links gets one list.
   This merges into the `systemd.nspawn.<mid>` unit produced in §6.1 through normal module
   merging.

2. **Bridge netdev.** `br-<BID>`, `Kind=bridge`, once per bridge.

3. **Enslavement.** Each `lh-*` gets a network with `Bridge=br-<BID>` and
   `LinkLocalAddressing=no`.

4. **Bridge network.** `LinkLocalAddressing=no`, `ConfigureWithoutCarrier=true`,
   `RequiredForOnline=false` — the bridge exists before any container boots and must never
   block `network-online.target`.

The host assigns **no address** on link bridges. They are pure L2 stitches; all L3 for
peer-to-peer traffic lives inside the guests.

### 6.3 Packet paths

```
container ──fe80::c──▶ ve-<mid> (fe80::1) ──▶ host routing ──▶ world / other containers
   (north/south: /128 host routes, host-forwarded)

container A ──lc-<h>──▶ lh-<h> ──▶ br-<BID> ◀── lh-<h'> ◀──lc-<h'>── container B
   (east/west: pure L2, host does not participate)
```

---

## 7. Invariants (assertions)

| Assertion | Why |
| --- | --- |
| MIDs unique across all groups | The IID is derived from the MID alone; duplicates collide in every prefix. |
| MID matches `[0-9a-f-]{36}` | Required by `--uuid=`; see the credential warning. |
| No link where `source == target` | A self-bridge is always a mistake. |
| BIDs unique | 48 bits after the `IFNAMSIZ` haircut. If this ever fires, the fix is to widen `getBIdentity` *and* shorten the `br-` prefix. |

---

## 8. The `_container` tree

`recursive ./_container` inlines everything below into every guest. Numeric prefixes encode
layering for humans; module order is irrelevant to Nix.

```
_container/config/
├── 01-administration/
│   ├── 01-authentication/by-user/01-root.nix   static
│   └── 02-credentials/credential.secret.nix    static  (pairs with the stable machine-id)
├── 02-nix/default.nix                          static
└── 02-network/
    ├── default.nix                             static
    └── 01-interfaces/
        ├── 01-host/default.nix                 static   — fe80::c + default route via fe80::1
        ├── 02-lo/default.nix                   static
        └── 03-lc-*/default.nix                 DYNAMIC  — one network per link
```

**Static** files are ordinary NixOS modules. **Dynamic** ones (`03-lc-*`) are generated at
guest-eval time from the address book:

```nix
{ sigil, ... }: {
  systemd.network.networks = sigil.self.links.lib.bridge.mapToAttrs (bridge: {
    "10-lc-${…}" = { matchConfig.Name = "lc-…"; /* addressing for this peer */ };
  });
}
```

This is the payoff of the `bridge`/`policy` split: `03-lc-*` uses `bridge` (symmetric,
includes incoming links); anything policy-shaped — firewalling, route preference — should
use `policy` and key off `pid`.

---

## 9. Extending the module

* **New guest-wide behaviour** → add a file under `_container/`. No wiring needed.
* **New per-container knob** → add an option in `containerModule`; it is in scope for the
  guest via `infosFor` only if you also add it there.
* **New guest-visible datum** → extend `infosFor`. That function *is* the guest API surface.
* **Host-side enforcement (firewall/routes per link)** → you have `pid` and both endpoints in
  `links.policies`; the corresponding `mkIf (cfg.settings.network.links != {})` branch is
  where it belongs.
* **New interface family** → add an `mk…Name` helper next to the existing three, and respect
  the 15-character budget.

---

## 10. Known rough edges

* **`builtins.trace` in the `config` section.** `links.collected`, `links.policies` and
  `links.bridges` each dump full JSON on every evaluation. Debug scaffolding — remove before
  it becomes load-bearing noise.
* **`links.<…>.source` is typed `str` but `apply` returns an attrset.** The type check runs
  on the pre-`apply` value; `config.source.mid` works, but the declared type lies. Same for
  `target`, typed `attrsOf raw` with no check that it is actually a container.
* **`freeformType` on groups** accepts any attribute as a container. Misspell an option and
  you get a container named after the typo, failing later with a confusing error.
* **`ula.source` has no default** despite a description implying one; it must be set whenever
  any container has a ULA.
* **The duplicate-MID assertion message says "ULA collision"** but the check is on MIDs. It is
  broader than the message suggests.
* **`Ephemeral=true`** — guest root filesystems do not persist. Anything stateful needs an
  explicit bind mount via `nspawn.config.filesConfig`.
* **Shadowing.** `self` in `__toString = self: self.mid` shadows the flake `self`; the inner
  `group` in `policies.incoming` is a group's *attrset*, not a group name. Both are correct,
  both read badly.
