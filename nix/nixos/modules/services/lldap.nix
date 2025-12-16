# Copyright (c) 2003-2025 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# ────────────────────────────────────────────────────────────────────────
# NOTE: This module keeps the general structure of the upstream one but
#       applies a few adjustments tailored to my setup. Only the pieces
#       I actually use are kept; unused options have been trimmed. Some
#       defaults have been changed/removed to reduce noise and clutter.
# ────────────────────────────────────────────────────────────────────────
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;

  cfg = config.services.lldap;

  tomlFormat = pkgs.formats.toml {};
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/databases/lldap.nix"
  ];

  options = let
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool enum listOf nullOr oneOf port str submodule;
  in {
    services.lldap = {
      enable = mkEnableOption "lldap";

      package = mkPackageOption pkgs "lldap" {};

      settings = mkOption {
        description = ''
          Default configuration.
          All the values can be overridden through environment variables, prefixed
          with "LLDAP_". For instance, "ldap_port" can be overridden with the
          "LLDAP_LDAP_PORT" variable.
        '';

        default = {};

        type = submodule {
          freeformType = tomlFormat.type;
          options = {
            verbose = mkOption {
              type = bool;
              description = ''
                Tune the logging to be more verbose by setting this to be true.
                You can set it with the LLDAP_VERBOSE environment variable.
              '';
              default = false;
            };

            ldap_host = mkOption {
              type = str;
              description = ''
                The host address that the LDAP server will be bound to.
                To enable IPv6 support, simply switch "ldap_host" to "::":
                To only allow connections from localhost (if you want to restrict to local self-hosted services),
                change it to "127.0.0.1" ("::1" in case of IPv6).
                If LLDAP server is running in docker, set it to "0.0.0.0" ("::" for IPv6) to allow connections
                originating from outside the container.
              '';
              default = "0.0.0.0";
            };

            ldap_port = mkOption {
              type = port;
              description = ''
                The port on which to have the LDAP server.
              '';
              default = 3890;
            };

            http_host = mkOption {
              type = str;
              description = ''
                The host address that the HTTP server will be bound to.
                To enable IPv6 support, simply switch "http_host" to "::".
                To only allow connections from localhost (if you want to restrict to local self-hosted services),
                change it to "127.0.0.1" ("::1" in case of IPv6).
                If LLDAP server is running in docker, set it to "0.0.0.0" ("::" for IPv6) to allow connections
                originating from outside the container.
              '';
              default = "0.0.0.0";
            };

            http_port = mkOption {
              type = port;
              description = ''
                The port on which to have the HTTP server, for user login and
                administration.
              '';
              default = 17170;
            };

            http_url = mkOption {
              type = str;
              description = ''
                The public URL of the server, for password reset links.
              '';
              default = "http://localhost";
            };

            assets_path = mkOption {
              type = str;
              description = ''
                The path to the front-end assets (relative to the working directory).
              '';
              default = "./app";
            };

            jwt_secret = mkOption {
              type = nullOr str;
              description = ''
                Random secret for JWT signature.
                This secret should be random, and should be shared with application
                servers that need to consume the JWTs.
                Changing this secret will invalidate all user sessions and require
                them to re-login.
                You should probably set it through the LLDAP_JWT_SECRET environment
                variable from a secret ".env" file.
                This can also be set from a file's contents by specifying the file path
                in the LLDAP_JWT_SECRET_FILE environment variable
                You can generate it with (on linux):
                LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\\'\'()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32; echo \'\'
              '';
              example = "REPLACE_WITH_RANDOM";
            };

            ldap_base_dn = mkOption {
              type = str;
              description = ''
                Base DN for LDAP.
                This is usually your domain name, and is used as a
                namespace for your users. The choice is arbitrary, but will be needed
                to configure the LDAP integration with other services.
                The sample value is for "example.com", but you can extend it with as
                many "dc" as you want, and you don't actually need to own the domain
                name.
              '';
              example = "dc=example,dc=com";
            };

            ldap_user_dn = mkOption {
              type = str;
              description = ''
                Admin username.
                For the LDAP interface, a value of "admin" here will create the LDAP
                user "cn=admin,ou=people,dc=example,dc=com" (with the base DN above).
                For the administration interface, this is the username.
              '';
              example = "admin";
            };

            ldap_user_email = mkOption {
              type = str;
              description = ''
                Admin email.
                Email for the admin account. It is only used when initially creating
                the admin user, and can safely be omitted.
              '';
              example = "admin@example.com";
            };

            ldap_user_pass = mkOption {
              type = nullOr str;
              description = ''
                Admin password.
                Password for the admin account, both for the LDAP bind and for the
                administration interface. It is only used when initially creating
                the admin user.
                It should be minimum 8 characters long.
                You can set it with the LLDAP_LDAP_USER_PASS environment variable.
                This can also be set from a file's contents by specifying the file path
                in the LLDAP_LDAP_USER_PASS_FILE environment variable
                Note: you can create another admin user for user administration, this
                is just the default one.
              '';
              example = "REPLACE_WITH_PASSWORD";
            };

            force_ldap_user_pass_reset = mkOption {
              type = oneOf [bool str (enum ["always"])];
              description = ''
                Force reset of the admin password.
                Break glass in case of emergency: if you lost the admin password, you
                can set this to true to force a reset of the admin password to the value
                of ldap_user_pass above.
                Alternatively, you can set it to "always" to reset every time the server starts.
              '';
              default = false;
            };

            database_url = mkOption {
              type = nullOr str;
              description = ''
                Database URL.
                This encodes the type of database (SQlite, MySQL, or PostgreSQL)
                , the path, the user, password, and sometimes the mode (when
                relevant).
                Note: SQlite should come with "?mode=rwc" to create the DB
                if not present.
                This can be overridden with the LLDAP_DATABASE_URL env variable.
              '';
              default = "sqlite:///var/lib/lldap/users.db?mode=rwc";
              example = "postgres://postgres-user:password@postgres-server/my-database";
            };

            key_file = mkOption {
              type = nullOr str;
              description = ''
                Private key file.
                Not recommended, use key_seed instead.
                Contains the secret private key used to store the passwords safely.
                Note that even with a database dump and the private key, an attacker
                would still have to perform an (expensive) brute force attack to find
                each password.
                Randomly generated on first run if it doesn't exist.
                Env variable: LLDAP_KEY_FILE
              '';
              example = "/var/lib/lldap/key";
            };

            key_seed = mkOption {
              type = nullOr str;
              description = ''
                Seed to generate the server private key, see key_file above.
                This can be any random string, the recommendation is that it's at least 12
                characters long.
                Env variable: LLDAP_KEY_SEED
              '';
              example = "RanD0m STR1ng";
            };

            ignored_user_attributes = mkOption {
              type = nullOr (listOf str);
              description = ''
                Ignored attributes.
                Some services will request attributes that are not present in LLDAP. When it
                is the case, LLDAP will warn about the attribute being unknown. If you want
                to ignore the attribute and the service works without, you can add it to this
                list to silence the warning.
              '';
              example = ["sAMAccountName"];
            };

            ignored_group_attributes = mkOption {
              type = nullOr (listOf str);
              description = ''
                Ignored attributes.
                Some services will request attributes that are not present in LLDAP. When it
                is the case, LLDAP will warn about the attribute being unknown. If you want
                to ignore the attribute and the service works without, you can add it to this
                list to silence the warning.
              '';
              example = ["mail" "userPrincipalName"];
            };

            smtp_options = mkOption {
              description = ''
                Options to configure SMTP parameters, to send password reset emails.
                To set these options from environment variables, use the following format
                (example with "password"): LLDAP_SMTP_OPTIONS__PASSWORD
              '';

              default = {};

              type = submodule {
                freeformType = tomlFormat.type;
                options = mkMerge [
                  {
                    enable_password_reset = mkOption {
                      type = bool;
                      description = ''
                        Whether to enabled password reset via email, from LLDAP.
                      '';
                      default = true;
                    };
                  }
                  (mkIf cfg.settings.smtp_options.enable_password_reset {
                    server = mkOption {
                      type = str;
                      description = ''
                        The SMTP server.
                      '';
                      example = "smtp.gmail.com";
                    };

                    port = mkOption {
                      type = port;
                      description = ''
                        The SMTP port.
                      '';
                      example = 587;
                    };

                    smtp_encryption = mkOption {
                      type = enum ["NONE" "TLS" "STARTTLS"];
                      description = ''
                        How the connection is encrypted, either "NONE" (no encryption), "TLS" or "STARTTLS".
                      '';
                      example = "TLS";
                    };

                    user = mkOption {
                      type = str;
                      description = ''
                        The SMTP user, usually your email address.
                      '';
                      example = "sender@gmail.com";
                    };

                    password = mkOption {
                      type = nullOr str;
                      description = ''
                        The SMTP password.
                      '';
                      example = "password";
                    };

                    from = mkOption {
                      type = nullOr str;
                      description = ''
                        The header field, optional: how the sender appears in the email. The first
                        is a free-form name, followed by an email between <>.
                      '';
                      example = "LLDAP Admin <sender@gmail.com>";
                    };

                    reply_to = mkOption {
                      type = nullOr str;
                      description = ''
                        Same for reply-to, optional.
                      '';
                      example = "Do not reply <noreply@localhost>";
                    };
                  })
                ];
              };
            };

            ldaps_options = mkOption {
              description = ''
                Options to configure LDAPS.
                To set these options from environment variables, use the following format
                (example with "port"): LLDAP_LDAPS_OPTIONS__PORT
              '';

              default = {};

              type = submodule {
                freeformType = tomlFormat.type;
                options = mkMerge [
                  {
                    enabled = mkOption {
                      type = bool;
                      description = ''
                        Whether to enable LDAPS.
                      '';
                      default = true;
                    };
                  }

                  (mkIf cfg.settings.ldaps_options.enabled {
                    port = mkOption {
                      type = port;
                      description = ''
                        Port on which to listen.
                      '';
                      default = 6360;
                    };

                    cert_file = mkOption {
                      type = str;
                      description = ''
                        Certificate file.
                      '';
                      example = "/data/cert.pem";
                    };

                    key_file = mkOption {
                      type = str;
                      description = ''
                        Certificate key file.
                      '';
                      example = "/data/key.pem";
                    };
                  })
                ];
              };
            };
          };
        };
      };

      environment = mkOption {
        type = attrsOf str;
        default = {};
        description = ''
          Environment variables passed to the service.
          Any config option name prefixed with `LLDAP_` takes priority over the one in the configuration file.
        '';
        example = {
          LLDAP_DATABASE_URL = "%d/database_url.encrypted";
          LLDAP_JWT_SECRET = "%d/jwt_secret.encrypted";
          LLDAP_LDAP_USER_PASS = "%d/ldap_user_pass.encrypted";
          LLDAP_KEY_SEED = "%d/key_seed.encrypted";
          LLDAP_SMTP_OPTIONS__PASSWORD = "%d/smtp_password.encrypted";
        };
      };
    };
  };

  config = let
    inherit (lib.strings) optionalString;
    inherit (lib.meta) getExe;
  in
    mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.settings.database_url != null || cfg.environment.LLDAP_DATABASE_URL != null;
        }
        {
          assertion = cfg.settings.jwt_secret != null || cfg.environment.LLDAP_JWT_SECRET != null || cfg.environment.LLDAP_JWT_SECRET_FILE != null;
        }
        {
          assertion = cfg.settings.key_seed != null || cfg.environment.key_file != null || cfg.environment.LLDAP_KEY_SEED != null || cfg.environment.LLDAP_KEY_FILE != null;
        }
        {
          assertion = cfg.settings.smtp_options.password != null || cfg.environment.LLDAP_SMTP_OPTIONS__PASSWORD != null;
        }
      ];

      systemd.services.lldap = {
        description = "lldap";

        wants = ["network-online.target"];
        after = ["network-online.target"];

        wantedBy = ["multi-user.target"];

        # lldap defaults to a hardcoded `jwt_secret` value if none is provided, which is bad, because
        # an attacker could create a valid admin jwt access token fairly trivially.
        # Because there are 3 different ways `jwt_secret` can be provided, we check if any one of them is present,
        # and if not, bootstrap a secret in `/var/lib/lldap/jwt_secret_file` and give that to lldap.
        script =
          optionalString (!cfg.settings ? jwt_secret) ''
            if [[ -z "$LLDAP_JWT_SECRET_FILE" ]] && [[ -z "$LLDAP_JWT_SECRET" ]]; then
              if [[ ! -e "./jwt_secret_file" ]]; then
                ${getExe pkgs.openssl} rand -base64 -out ./jwt_secret_file 32
              fi
              export LLDAP_JWT_SECRET_FILE="./jwt_secret_file"
            fi
          ''
          + ''
            ${getExe cfg.package} run --config-file ${tomlFormat.generate "lldap_config.toml" cfg.settings}
          '';
        serviceConfig = {
          StateDirectory = "lldap";
          StateDirectoryMode = "0750";
          WorkingDirectory = "%S/lldap";
          UMask = "0027";
          User = "lldap";
          Group = "lldap";
          DynamicUser = true;
        };
        inherit (cfg) environment;
      };
    };
}
