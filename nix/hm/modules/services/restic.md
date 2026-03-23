# `services.restic` — Module Documentation

A module for scheduling automated, periodic backups using [Restic](https://restic.net/). Each backup target is managed as a systemd user service and timer, with credentials injected at runtime via a credential helper.

---

## Options

### `services.restic.enable`

**Type:** `bool`  
**Default:** `false`

Enables the Restic backup module. Must be set to `true` for any backup configuration to take effect.

---

### `services.restic.package`

**Type:** `package`  
**Default:** `pkgs.restic`

The Restic package to use.

---

### `services.restic.periodic`

**Type:** `attrsOf (submodule)`  
**Default:** `{}`

An attribute set of named backup configurations. Each attribute name becomes the unique identifier for that backup job, and determines the names of the generated systemd service and timer units.

Each entry supports the following sub-options:

#### `periodic.<name>.target`

**Type:** `path`  
**Required:** yes

The directory to back up. A NixOS assertion will fail at evaluation time if this is not set.

#### `periodic.<name>.flags`

**Type:** `listOf str`  
**Default:** `[]`

A list of additional flags passed verbatim to `restic backup`. Useful for options like `--one-file-system`, `--verbose`, or `--tag`.

#### `periodic.<name>.exclude`

**Type:** `listOf str`  
**Default:** `[]`

A list of exclude patterns passed to `restic backup`. These follow Restic's standard exclusion syntax — see the [Restic documentation](https://restic.readthedocs.io/en/stable/040_backup.html#excluding-files) for details.

**Example:**
```nix
exclude = [
  "/var/cache"
  "/home/*/.cache"
  ".git"
];
```

#### `periodic.<name>.name` *(internal)*

**Type:** `str`  
**Read-only**

The attribute name of the backup configuration. Set automatically; do not override.

#### `periodic.<name>.serviceUnitName` *(internal)*

**Type:** `str`  
**Read-only**

The name of the generated systemd user service unit, set to `backup@<name>`. This is useful when you need to reference the unit in other systemd configuration, such as `EnvironmentFile` or `Wants`.

---

## Credentials

Each backup job expects the following credentials to be provided at runtime via the systemd credential mechanism. Credentials should be registered under the service unit name `restic@<name>`.

| Credential name         | Description                                      |
|-------------------------|--------------------------------------------------|
| `aws-access-key-id`     | AWS access key (mapped to `AWS_ACCESS_KEY_ID`)   |
| `aws-secret-access-key` | AWS secret key (mapped to `AWS_SECRET_ACCESS_KEY`) |
| `restic-password`       | Repository encryption password (`RESTIC_PASSWORD`) |
| `restic-repository`     | Repository URL or path (`RESTIC_REPOSITORY`)     |

These are injected into the backup script's environment at runtime and are never written to the Nix store.

---

## Generated systemd Units

For each entry in `periodic`, the module generates:

- **`restic@<name>.service`** — a oneshot systemd user service that runs `restic backup` against the configured target. It runs after `network-online.target`, uses a private `/tmp`, and creates isolated runtime and cache directories under `backup/<name>`.
- **`restic@<name>.timer`** — a systemd user timer that triggers the corresponding service. The timer is added to `timers.target`.

> **Note:** The timer unit does not currently configure an `OnCalendar` or `OnBootSec` schedule in this module. You will need to extend the timer unit or configure the schedule externally to control when backups run.

---

## Example Configuration

```nix
services.restic = {
  enable = true;
  periodic = {
    home = {
      target = "${config.home.homeDirectory}/03 Dokumente";
      flags = [
        "--compression max"
      ];
    };
    documents = {
      target = "${config.home.homeDirectory}/02 Bibliothek";
      flags = [
        "--compression max"
      ];
    };
  };
};
```

This produces two backup jobs: `restic@home.service` / `restic@home.timer` and `restic@documents.service` / `restic@documents.timer`.

---

## Notes

- This is a **user-level** module — all generated systemd units are placed under `systemd.user`, not system-level `systemd`.
- The backup script is generated as a Nix derivation (`pkgs.custom.writeShell`), so the script content (including the target path and flags) is stored in the Nix store. Only secrets are injected via credentials at runtime.
- `exclude` patterns are not yet wired into the generated `restic backup` command in the current implementation — only `target` and `flags` are passed. If you need excludes, pass them manually via `flags` using `--exclude` or `--exclude-file`.