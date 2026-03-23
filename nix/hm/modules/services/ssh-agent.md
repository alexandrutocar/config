# `services.ssh-agent` — Module Documentation

A simplified rewrite of the upstream Home Manager `ssh-agent` module. Manages an
OpenSSH key agent as a systemd socket-activated user service, and exports
`SSH_AUTH_SOCK` into login sessions.

> **Linux only.** Enabling this module on a non-Linux platform will trigger an
> assertion failure at evaluation time.

---

## Options

### `services.ssh-agent.enable`

|         |           |
|---------|-----------|
| Type    | `boolean` |
| Default | `false`   |

Enable the OpenSSH private key agent service.

---

### `services.ssh-agent.package`

|         |                |
|---------|----------------|
| Type    | `package`      |
| Default | `pkgs.openssh` |

The OpenSSH package from which the `ssh-agent` binary is taken.

---

## Credentials

Keys are not loaded automatically. After enabling the module and logging in, add
keys manually:

```bash
# Add a specific key
ssh-add ~/.ssh/id_ed25519

# List currently loaded keys
ssh-add -l

# Remove all keys from the agent
ssh-add -D
```

To load keys automatically at login, use `ssh-add` from a shell profile or a
separate systemd user service that runs after `ssh-agent.service`.

---

## Generated System Units

Enabling the module writes two systemd user units.

### `ssh-agent.socket`

Socket unit that creates the agent socket and triggers the service on first
connection.

| Field                  | Value                                                         |
|------------------------|---------------------------------------------------------------|
| `ListenStream`         | `%t/ssh-agent.socket` → `/run/user/<UID>/ssh-agent.socket`    |
| `RemoveOnStop`         | `true` — socket file is cleaned up on stop                    |
| `WantedBy`             | `sockets.target`                                              |
| `ConditionEnvironment` | `!SSH_AGENT_PID` — skipped if already inside an agent session |

### `ssh-agent.service`

Service unit that runs the agent in foreground mode (`-D`), kept alive by systemd
rather than daemonising itself.

| Field                  | Value                                                         |
|------------------------|---------------------------------------------------------------|
| `ExecStart`            | `ssh-agent -D`                                                |
| `SuccessExitStatus`    | `2` — exit code 2 is treated as clean shutdown                |
| `Requires`             | `ssh-agent.socket`                                            |
| `ConditionEnvironment` | `!SSH_AGENT_PID` — skipped if already inside an agent session |

### `SSH_AUTH_SOCK` session variable

The module appends the following to `home.sessionVariablesExtra`, evaluated in
every login shell:

```sh
if [ -z "$SSH_AUTH_SOCK" -o -z "$SSH_CONNECTION" ]; then
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket
fi
```

The guard prevents overwriting an existing `SSH_AUTH_SOCK`. This means that if
another agent (such as GNOME Keyring / `gcr`) sets the variable earlier in the
session, this module's socket will not take over. See Notes below.

---

## Example Configuration

Minimal — use the default `openssh` package:

```nix
services.ssh-agent.enable = true;
```

Custom package:

```nix
services.ssh-agent = {
  enable = true;
  package = pkgs.openssh_gssapi;
};
```

---

## Notes

### Conflict with GNOME Keyring

GNOME Keyring includes a built-in SSH agent that sets `SSH_AUTH_SOCK` before
login shell variables are evaluated. When this happens the guard condition in
`sessionVariablesExtra` is false and `SSH_AUTH_SOCK` continues to point at the
GCR socket (`/run/user/<UID>/gcr/ssh`), not this module's socket.

To disable the GNOME Keyring SSH component:

```nix
# In your Home Manager configuration
xdg.configFile."autostart/gnome-keyring-ssh.desktop".text = ''
  [Desktop Entry]
  Type=Application
  Name=GNOME Keyring: SSH Agent
  X-GNOME-Autostart-enabled=false
'';
```

Or unconditionally force `SSH_AUTH_SOCK` by overriding `sessionVariablesExtra`
directly in your config after importing this module:

```nix
home.sessionVariablesExtra = ''
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
'';
```

### Relationship to the upstream module

This module sets `disabledModules = [ "services/ssh-agent.nix" ]` and replaces
the upstream implementation entirely. Do not import both.

### Socket activation behaviour

`ssh-agent.service` starts on the first connection to the socket, not at login.
Until a client connects, the service is `inactive (dead)` — this is expected.
The socket unit remains `active (listening)` throughout the session.