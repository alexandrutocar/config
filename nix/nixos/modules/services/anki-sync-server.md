# Anki Sync Server {#module-services-anki-sync-server}

[Anki Sync Server](https://docs.ankiweb.net/sync-server.html) is the built-in sync server, present in recent versions of Anki. Advanced users who cannot or do not wish to use AnkiWeb can use this sync server instead of AnkiWeb.

This module is compatible only with Anki versions >=2.1.66, due to [recent enhancements to the Nix' Anki package](https://github.com/NixOS/nixpkgs/commit/05727304f8815825565c944d012f20a9a096838a).

## Basic Usage {#module-services-anki-sync-server-basic-usage}

By default, the module creates a [`systemd`](https://www.freedesktop.org/wiki/Software/systemd/) unit which runs the sync server with an isolated user using the systemd `DynamicUser` option.

This can be done by enabling the `anki-sync-server` service:
```nix
{ ... }:

{
  services.anki-sync-server.enable = true;
}
```

It is necessary to set at least one username-password pair under
{option}`services.anki-sync-server.settings.user`. For example

```nix
{
  services.anki-sync-server.settings.user = [
    {
      username = "Max Musterman";
      password.cred = ''
        ...
      '';
    }
  ];
}
```

Here, `password.cred` is the encrypted credential containing the password.

By default, synced data are stored in */var/lib/anki-sync-server/*ankiuser**.
You can change the directory by using `services.anki-sync-server.settings.base`

```nix
{ services.anki-sync-server.settings.base = "/home/anki/data"; }
```

By default, the server listen address {option}`services.anki-sync-server.settings.host` is set to localhost, listening on port {option}`services.anki-sync-server.settings.port`. If you want to expose the sync server on your local network, then set the following options:

```nix
{options, ...}: {
  services.anki-sync-server.settings.host = "0.0.0.0";

  networking.firewall.allowedTCPPorts = [
    options.services.anki-sync-server.settings.port
  ];
}
```
