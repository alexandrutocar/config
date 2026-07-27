# Davis {#module-services-davis}

[Davis](https://github.com/tchapi/davis/) is a CalDav and CardDav server. It
has a simple, fully translatable admin interface for sabre/dav based on Symfony
5 and Bootstrap 5, initially inspired by Baïkal.

## Basic Usage {#module-services-davis-basic-usage}

First, an application secret is needed, this can be generated with:

```ShellSession
$ cat /dev/urandom | tr -dc a-zA-Z0-9 | fold -w 48 | head -n 1
```

After that, `davis` can be deployed like this:

```nix
{
  services.davis = {
    enable = true;

    settings = {
      hostname = "davis.example.com";
      mail = {
        dsn = "smtp://username@example.com:25";
        inviteFromAddress = "davis@example.com";
      };
    };
  };
}
```

This deploys Davis using a sqlite database running out of `/var/lib/davis`.

Logs can be found in `/var/lib/davis/var/log/`.
