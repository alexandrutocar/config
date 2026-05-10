# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀▄ █▀▄▀█ █ █▄░█ █ █▀ ▀█▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
# █▀█ █▄▀ █░▀░█ █ █░▀█ █ ▄█ ░█░ █▀▄ █▀█ ░█░ █ █▄█ █░▀█
#
# system users, security policies, and early boot emergency access...
#
# ────────────────────────────────────────────────────────────────────────
{
  self,
  lib,
  ...
}: {
  imports = lib.lists.singleton (self + /etc/shared/01-settings/administration.nix);

  users.users = {
    root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN1biuTFWEqGFZf044otVrbAJFRFBdIvc+/oJLkVfYnd root@lumine"
      ];

      initialHashedPassword = "$y$j9T$uFXBUysQPX8xzEe9SQBrS0$o9isJAqaqNb2iz1KxLyqqa82hJwNN.yCM60Z4h56KAC";
    };

    alex = {
      isNormalUser = true;

      extraGroups = [
        "video"
        "input"
        "wheel"
      ];

      openssh = {
        authorizedKeys = {
          keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAGnMalGnqtkuQKQfYF1lvJHVA9YKvi94Vg/9rHvKqKZ alex@lumine"
          ];
        };
      };

      initialHashedPassword = "$y$j9T$2vrNLqCgONznFy/EeJuTb/$INYuTJVmZLkwGoABqfhOrPvAKeZdmnHPzCGmvjHvnN0";
    };
  };

  isoImage.contents = [
    {
      source = /home/alex/.ssh/keys.d/lumine_ssh_host_rsa_key;
      target = "/ssh_host_rsa_key"; # /iso/ssh_host_rsa_key
    }
    {
      source = /home/alex/.ssh/keys.d/lumine_ssh_host_rsa_key.pub;
      target = "/ssh_host_rsa_key.pub"; # /iso/ssh_host_rsa_key.pub
    }
    {
      source = /home/alex/.ssh/keys.d/lumine_ssh_host_ed25519_key;
      target = "/ssh_host_ed25519_key"; # /iso/ssh_host_ed25519_key
    }
    {
      source = /home/alex/.ssh/keys.d/lumine_ssh_host_ed25519_key.pub;
      target = "/ssh_host_ed25519_key.pub"; # /iso/ssh_host_ed25519_key.pub
    }
  ];

  system.activationScripts.sshd.text = ''
    FILES=(
      "/iso/ssh_host_rsa_key"
      "/iso/ssh_host_rsa_key.pub"
      "/iso/ssh_host_ed25519_key"
      "/iso/ssh_host_ed25519_key.pub"
    )

    for FILE in "''${FILES[@]}"; do
        if [ -e "$FILE" ]; then
            echo "$FILE exists. Copying to /etc/ssh"
            cp "$FILE" /etc/ssh/

            BASENAME=$(basename "$FILE")
            TARGET="/etc/ssh/$BASENAME"

            # Set correct permissions:
            if [[ "$BASENAME" == *.pub ]]; then
                chmod 444 "$TARGET"  # Public keys: readable by all
            else
                chmod 400 "$TARGET"  # Private keys: owner read-only
            fi

            echo "Permissions set for $TARGET."
        else
            echo "$FILE does not exist."
        fi
    done
  '';
}
