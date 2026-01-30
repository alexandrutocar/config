# ────────────────────────────────────────────────────────────────────────
#
# █▀▄▀█ ▄▀█ █▀▄ █▀▄ █▄█
# █░▀░█ █▀█ █▄▀ █▄▀ ░█░
#
# maddy, main server, communication...
#
# ────────────────────────────────────────────────────────────────────────
{options, ...}: {
  services.maddy = {
    enable = true;
    primaryDomain = "aether.ip";
    ensureAccounts = [
      "router@aether.ip"
      "aether@aether.ip"
    ];
    ensureCredentials = {
      "router@aether.ip".passwordFile = "/usr/router/password.txt";
      "aether@aether.ip".passwordFile = "/usr/aether/password.psk";
    };

    tls = {
      loader = "file";
      certificates = [
        {
          keyPath = "/etc/ssl/mx1.example.org.key";
          certPath = "/etc/ssl/mx1.example.org.crt";
        }
      ];
    };

    config =
      builtins.replaceStrings [
        "imap tcp://0.0.0.0:143"
        "submission tcp://0.0.0.0:587"
      ] [
        "imap tls://0.0.0.0:993 tcp://0.0.0.0:143"
        "submission tls://0.0.0.0:465 tcp://0.0.0.0:587"
      ]
      options.services.maddy.config.default;
  };
}
