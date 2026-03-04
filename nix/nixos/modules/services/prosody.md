# Prosody {#module-services-prosody}

[Prosody](https://prosody.im/) is an open-source, modern XMPP server.

## Basic usage {#module-services-prosody-basic-usage}

A common struggle for most XMPP newcomers is to find the right set of XMPP Extensions (XEPs) to setup. Forget to activate a few of those and your XMPP experience might turn into a nightmare!

The XMPP community tackles this problem by creating a meta-XEP listing a decent set of XEPs you should implement. This meta-XEP is issued every year, the 2020 edition being [XEP-0423](https://xmpp.org/extensions/xep-0423.html).

The NixOS Prosody module will implement most of these recommended XEPs out of the box. That being said, two components still require some
manual configuration: the [Multi User Chat (MUC)](https://xmpp.org/extensions/xep-0045.html) and the [HTTP File Upload](https://xmpp.org/extensions/xep-0363.html) ones. You'll need to create a DNS subdomain for each of those. The current convention is to name your MUC endpoint `conference.example.org` and your HTTP upload domain `upload.example.org`.

A good configuration to start with, including a [Multi User Chat (MUC)](https://xmpp.org/extensions/xep-0045.html) endpoint as well as a [HTTP File Upload](https://xmpp.org/extensions/xep-0363.html) endpoint will look like this:

```nix
{
  services.prosody = {
    enable = true;

    settings = {
      VirtualHost = {
        "example.org" = {
          enable = true;
          domain = "example.org";
          admins = [
            "admin@example.org"
          ];
          
          ssl = {
            certificate = "/var/lib/acme/example.org/fullchain.pem";
            key = "/var/lib/acme/example.org/key.pem";
          };

          muc = [
            {
              domain = "conference.example.org";
            }
          ];
        };
      };
    };
  };
}
```
