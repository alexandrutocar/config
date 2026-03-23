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
# TODO: https://arcanican.is/guides/prosody.php
# TODO:
{
  options,
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (lib.generators) mkLuaInline mkKeyValueDefault toLua toKeyValue;
  inherit (lib.lists) optional;
  inherit (lib.strings) concatStringsSep optionalString;
  inherit (lib.trivial) boolToString;

  cfg = config.services.prosody;
in {
  # Disabled the upstream module,
  # This is a simplified rewrite.
  disabledModules = [
    "services/networking/prosody.nix"
    "services/web-apps/jitsi-meet.nix" # expects upstream module
  ];

  options = let
    inherit (lib.extra.attrsets) mergeAttrsList;
    inherit (lib.options) mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrs attrsOf bool enum int lines listOf nullOr oneOf path port str submodule;
  in {
    services.prosody = {
      enable = mkEnableOption "Prosody";

      package = mkPackageOption pkgs "prosody" {
        example = ''
          pkgs.prosody.override {
            withExtraLibs = [ pkgs.luaPackages.lpty ];
            withCommunityModules = [ "auth_external" ];
          };
        '';
      };

      settings = let
        modules = {
          # see https://prosody.im/doc/modules/mod_account_activity
          mod_account_activity = {}; # has no special configuration

          # see https://prosody.im/doc/modules/mod_adhoc
          mod_adhoc = {}; # has no special configuration

          # see https://prosody.im/doc/modules/mod_admin_adhoc
          mod_admin_adhoc = {}; # has no special configuration

          # see https://prosody.im/doc/modules/mod_admin_shell
          mod_admin_shell = {}; # has no special configuration

          # see https://prosody.im/doc/modules/mod_admin_socket
          mod_admin_socket = {
            admin_socket = mkOption {
              type = path;
              default = "prosody.sock";
              description = ''
                UNIX socket relative to the Prosody data directory.
              '';
            };
          };

          # see https://prosody.im/doc/modules/mod_admin_telnet
          mod_admin_telnet = {
            console_ports = mkOption {
              type = listOf port;
              default = [5582];
              description = ''
                Which ports to listen on for telnet connections.
              '';
            };
          };

          # see https://prosody.im/doc/modules/mod_announce
          mod_announce = {}; # has no special configuration

          # see https://prosody.im/doc/modules/mod_blocklist
          mod_blocklist = {
            bounce_blocked_messages = mkOption {
              type = bool;
              default = false;
              description = ''
                TODO: Better description.
                Supported in 0.12.5+, defaults to false
                Older versions always bounced blocked messages
              '';
            };
            blocklist_cache_size = mkOption {
              type = int;
              default = 64;
              description = ''
                TODO: Better description.
                By default Prosody keeps an in-memory cache of the
                blocklists of up to 64 users
              '';
            };
          };

          # see https://prosody.im/doc/modules/mod_bookmarks
          mod_bookmarks = {}; # has no special configuration

          # see https://prosody.im/doc/modules/mod_bosh
          mod_bosh = {
            bosh_max_inactivity = mkOption {
              type = int;
              default = 60;
              description = ''
                Maximum amount of time in seconds a client may remain silent for, with no requests.
              '';
            };
            consider_bosh_secure = mkOption {
              type = bool;
              default = false;
              description = ''
                If true then BOSH connections will be allowed when requiring encryption, even if unencrypted.
              '';
            };
          };

          # see https://prosody.im/doc/modules/mod_c2s
          # see https://prosody.im/doc/modules/mod_carbons
          # see https://prosody.im/doc/modules/mod_cloud_notify
          # see https://prosody.im/doc/modules/mod_component
          # see https://prosody.im/doc/modules/mod_compression
          # see https://prosody.im/doc/modules/mod_cron
          # see https://prosody.im/doc/modules/mod_csi
          # see https://prosody.im/doc/modules/mod_csi_simple
          # see https://prosody.im/doc/modules/mod_debug_sql
          # see https://prosody.im/doc/modules/mod_dialback
          # see https://prosody.im/doc/modules/mod_disco
          # see https://prosody.im/doc/modules/mod_external_services
          # see https://prosody.im/doc/modules/mod_flags
          # see https://prosody.im/doc/modules/mod_groups
          # see https://prosody.im/doc/modules/mod_http
          # see https://prosody.im/doc/modules/mod_http_altconnect
          # see https://prosody.im/doc/modules/mod_http_errors
          # see https://prosody.im/doc/modules/mod_http_files
          # see https://prosody.im/doc/modules/mod_http_file_share
          # see https://prosody.im/doc/modules/mod_http_openmetrics
          # see https://prosody.im/doc/modules/mod_invites
          # see https://prosody.im/doc/modules/mod_invites_adhoc
          # see https://prosody.im/doc/modules/mod_invites_register
          # see https://prosody.im/doc/modules/mod_iq
          # see https://prosody.im/doc/modules/mod_lastactivity
          # see https://prosody.im/doc/modules/mod_legacyauth
          # see https://prosody.im/doc/modules/mod_limits
          # see https://prosody.im/doc/modules/mod_mam
          # see https://prosody.im/doc/modules/mod_message
          # see https://prosody.im/doc/modules/mod_mimicking
          # see https://prosody.im/doc/modules/mod_motd
          # see https://prosody.im/doc/modules/mod_muc
          # see https://prosody.im/doc/modules/mod_muc_mam
          # see https://prosody.im/doc/modules/mod_muc_unique
          # see https://prosody.im/doc/modules/mod_net_multiplex
          # see https://prosody.im/doc/modules/mod_offline
          # see https://prosody.im/doc/modules/mod_pep
          # see https://prosody.im/doc/modules/mod_pep_simple
          # see https://prosody.im/doc/modules/mod_ping
          # see https://prosody.im/doc/modules/mod_posix
          # see https://prosody.im/doc/modules/mod_presence
          # see https://prosody.im/doc/modules/mod_privacy
          # see https://prosody.im/doc/modules/mod_private
          # see https://prosody.im/doc/modules/mod_proxy65
          # see https://prosody.im/doc/modules/mod_pubsub

          # see https://prosody.im/doc/modules/mod_register
          mod_register = {
            allow_registration = mkOption {
              type = bool;
              default = false;
              description = ''
                Whether to allow registration of new accounts via Jabber clients.
              '';
            };
          };

          # see https://prosody.im/doc/modules/mod_register_ibr
          # see https://prosody.im/doc/modules/mod_register_limits
          # see https://prosody.im/doc/modules/mod_roster
          # see https://prosody.im/doc/modules/mod_server_info
          # see https://prosody.im/doc/modules/mod_s2s_auth_certs
          # see https://prosody.im/doc/modules/mod_s2s_auth_dane_in
          # see https://prosody.im/doc/modules/mod_s2s_bidi
          # see https://prosody.im/doc/modules/mod_s2s
          # see https://prosody.im/doc/modules/mod_saslauth
          # see https://prosody.im/doc/modules/mod_scansion_record
          # see https://prosody.im/doc/modules/mod_server_contact_info
          # see https://prosody.im/doc/modules/mod_smacks
          # see https://prosody.im/doc/modules/mod_stanza_debug
          # see https://prosody.im/doc/modules/mod_time
          # see https://prosody.im/doc/modules/mod_tls
          # see https://prosody.im/doc/modules/mod_tokenauth
          # see https://prosody.im/doc/modules/mod_tombstones
          # see https://prosody.im/doc/modules/mod_turn_external
          # see https://prosody.im/doc/modules/mod_unknown
          # see https://prosody.im/doc/modules/mod_uptime
          # see https://prosody.im/doc/modules/mod_user_account_management
          # see https://prosody.im/doc/modules/mod_vcard4
          # see https://prosody.im/doc/modules/mod_vcard)
          # see https://prosody.im/doc/modules/mod_vcard_legacy
          # see https://prosody.im/doc/modules/mod_version
          # see https://prosody.im/doc/modules/mod_watchregistrations
          # see https://prosody.im/doc/modules/mod_websocket
          # see https://prosody.im/doc/modules/mod_welcome
          # see https://prosody.im/doc/modules/mod_windows
        };

        host = mergeAttrsList [
          {
            modules_enabled = mkOption {
              type = listOf (enum [
                # ------------------
                # Generally Required
                # ------------------
                "disco" # Service discovery.
                "roster" # Allow users to have a roster.
                "sslauth" # Authentication for clients and servers.
                # Recommended if you want to log in.
                "tls" # Add support for secure TLS on c2s/s2s connections.

                # ------------------------------
                # Not essential, but recommended
                # ------------------------------
                "blocklist" # Allow users to block communications with other users.
                "bookmarks" # Synchronize the list of open rooms between clients.
                "carbons" # Keep multiple clients in sync.
                "dialback" # Support for verifying remote servers using DNS.
                "limits" # Enable bandwidth limiting for XMPP connections.
                "pep" # Allow users to store public and private data in their account.
                "private" # Legacy account storage mechanism (XEP-0049).
                "smacks" # Stream management and resumption (XEP-0198).
                "vcard4" # User profiles (stored in PEP).
                "vcard_legacy" # Conversion between legacy vCard and PEP Avatar.

                # ------------
                # Nice to have
                # ------------
                "csi_simple" # Simple but effective traffic optimizations for mobile devices.
                "invites" # Create and manage invites.
                "invites_adhoc" # Allow admins/users to create invitations via their client.
                "invites_register" # Allows invited users to create accounts.
                "ping" # Replies to XMPP pings with pongs.
                "register" # Allow users to register on this server using a client and change passwords.
                "time" # Let others know the time here on this server.
                "uptime" # Report how long server has been running.
                "version" # Replies to server version requests.
                "mam" # Store recent messages to allow multi-device synchronization.
                "turn_external" # Provide external STUN/TURN service for e.g. audio/video calls.

                # ----------------
                # Admin interfaces
                # ----------------
                "admin_adhoc" # Allows administration via an XMPP client that supports ad-hoc commands.
                "admin_shell" # Allow secure administration via 'prosodyctl shell'.

                # ------------
                # HTTP modules
                # ------------
                "bosh" # Enable BOSH clients, aka "Jabber over HTTP".
                "http_openmetrics" # Enable exposing metrics to stats collectors.
                "websocket" # Enable XMPP over WebSockets.

                # ----------------------------
                # Other specific functionality
                # ----------------------------
                "announce" # Send announcement to all online users.
                "groups" # Shared roster support.
                "legacyauth" # Legacy authentication. Only used by some old clients and bots.
                "mimicking" # Prevent address spoofing.
                "motd" # Send a message to users when they log in.
                "proxy65" # Enables a file transfer proxy service which clients behind NAT can use.
                "s2s_bidi" # Bi-directional server-to-server (XEP-0288).
                "server_contact_info" # Publish contact information for this service.
                "tombstones" # Prevent registration of deleted accounts.
                "watchregistrations" # Alert admins of registrations.
                "welcome" # Welcome users who register accounts.
              ]);
              default = [
                "disco"
                "roster"
                "sslauth"
                "tls"

                "blocklist"
                "bookmarks"
                "carbons"
                "dialback"
                "limits"
                "pep"
                "private"
                "smacks"
                "vcard4"
                "vcard_legacy"

                "csi_simple"
                "invites"
                "invites_adhoc"
                "invites_register"
                "ping"
                "register"
                "time"
                "uptime"
                "version"
                # "mam"
                # "turn_external"

                "admin_adhoc"
                "admin_shell"

                # "bosh"
                # "http_openmetrics"
                # "websocket"

                # "announce"
                # "groups"
                # "legacyauth"
                # "mimicking"
                # "motd"
                # "proxy65"
                # "s2s_bidi"
                # "server_contact_info"
                # "tombstones"
                # "watchregistrations"
                # "welcome"
              ];

              description = ''
                List of modules to load for the host.
                Documentation for bundled modules can be found at <https://prosody.im/doc/modules>.
              '';
            };

            modules_disabled = mkOption {
              type = listOf (enum [
                "offline" # Store offline messages.
                "c2s" # Handle client connections.
                "s2s" # Handle server-to-server connections.
                "posix" # POSIX functionality, sends server to background, etc.
              ]);
              default = [];
              description = ''
                Allows you to disable the loading of a list of modules for a particular host,
                or all hosts if those modules are set in the global section.
              '';
            };

            admins = mkOption {
              type = listOf str;
              default = [];
              example = [
                "admin1@example.com"
                "admin2@example.com"
              ];
              description = ''
                This is a (by default, empty) list of accounts that are admins for the server.
                Note that you must create the accounts separately (see <https://prosody.im/doc/creating_accounts> for info).
              '';
            };

            authentication = mkOption {
              type = enum [
                "internal_plain"
                "internal_hashed"
                "cyrus"
                "anonymous"
              ];
              default = "internal_hashed";
              example = "internal_plain";
              description = ''
                Choose what authentication plugin will be used on this host (or all hosts if in the global section).
                For more information see [Authentication providers](https://prosody.im/doc/authentication).
              '';
            };
          }
          modules.mod_register
        ];
      in
        mergeAttrsList [
          {
            inherit (host) modules_enabled modules_disabled;

            # ────────────────────────────────────────────────────────────────────────
            # GENERAL SERVER SETTINGS
            # ────────────────────────────────────────────────────────────────────────
            log = mkOption {
              type = lines;
              default = ''"*syslog"'';
              description = "See [Logging Configuration](https://prosody.im/doc/logging) for more details.";
              example = ''
                {
                  { min = "warn"; to = "*syslog"; };
                }
              '';
            };

            data_path = mkOption {
              type = path;
              default = "/var/lib/prosody";
              description = ''
                Location of the Prosody data storage directory, without a trailing
                slash. The default path depends on your system and how you installed
                Prosody. If you installed from packages on a Linux-based platform,
                this is usually /var/lib/prosody.
              '';
            };

            plugin_paths = mkOption {
              type = listOf path;
              default = [];
              description = ''
                This option allows you to specify additional locations where Prosody will search first for modules.
                For additional modules you can install, see the community module repository at <https://modules.prosody.im>.
              '';
            };

            # ────────────────────────────────────────────────────────────────────────
            # PORT AND NETWORK SETTINGS
            # ────────────────────────────────────────────────────────────────────────

            # ----------------
            # CLIENT-TO-SERVER
            # ----------------
            c2s_ports = mkOption {
              type = listOf port;
              default = [5222];
              description = ''
                Ports on which to listen for client connections. Default is [ 5222 ].
              '';
            };

            c2s_interfaces = mkOption {
              type = listOf str;
              default = ["0.0.0.0" "::"];
              example = ["127.0.0.1" "::1"];
              description = ''
                Interfaces on which to listen for client connections. Defaults to default interfaces.
              '';
            };

            c2s_timeout = mkOption {
              type = int;
              default = 300;
              description = ''
                Timeout unauthenticated client connections. Defaults to 300 i.e. 5 minutes.
              '';
            };

            # ----------
            # DEPRECATED
            #-----------
            # legacy_ssl_ports = mkOption {
            #   type = nullOf (listOf port);
            #   example = [ 5443 ];
            #   description = ''
            #     Ports on which to listen for SSL connections. Disabled by default.
            #     Deprecated, use c2s_direct_tls_ports instead.
            #   '';
            # };

            # ----------
            # DEPRECATED
            #-----------
            # legacy_ssl_interfaces = mkOption {
            #   type = nullOf (listOf str);
            #   example = [ "127.0.0.1" "::1" ];
            #   description = ''
            #     Interfaces on which to listen for legacy SSL connections. Defaults to default interfaces.
            #     Deprecated, use c2s_direct_tls_interfaces instead.
            #   '';
            # };

            c2s_direct_tls_ports = mkOption {
              type = listOf port;
              default = [];
              example = [5222];
              description = ''
                Ports on which to listen for [XMPP over TLS](https://xmpp.org/extensions/xep-0368.html) client connections.
                Disabled by default. Available starting with [0.12.0](https://prosody.im/doc/release/0.12.0).
              '';
            };

            c2s_direct_tls_interfaces = mkOption {
              type = nullOr (listOf port);
              default = ["0.0.0.0" "::"];
              example = ["127.0.0.1" "::1"];
              description = ''
                Interfaces on which to listen for [XMPP over TLS](https://xmpp.org/extensions/xep-0368.html) client connections.
                Defaults to [default interfaces](https://prosody.im/doc/ports#default_interfaces). Available starting with [0.12.0](https://prosody.im/doc/release/0.12.0).
              '';
            };

            # ----------------
            # SERVER-TO-SERVER
            # ----------------
            s2s_ports = mkOption {
              type = listOf port;
              default = [5269];
              description = ''
                Ports on which to listen for server-to-server connections.
              '';
            };

            s2s_interfaces = mkOption {
              type = listOf str;
              default = ["0.0.0.0" "::"];
              example = ["127.0.0.1" "::1"];
              description = ''
                Interfaces on which to listen for server-to-server connections.
                Defaults to [default interfaces](https://prosody.im/doc/ports#default_interfaces).
              '';
            };

            s2s_timeout = mkOption {
              type = int;
              default = 90;
              description = ''
                Timeout for unauthenticated server connections. Default is 90 seconds.
              '';
            };

            s2s_direct_tls_ports = mkOption {
              type = listOf port;
              default = [];
              example = [5222];
              description = ''
                Ports on which to listen for [XMPP over TLS](https://xmpp.org/extensions/xep-0368.html) server-to-server connections.
                Disabled by default. Available starting with [0.12.0](https://prosody.im/doc/release/0.12.0).
              '';
            };

            s2s_direct_tls_interfaces = mkOption {
              type = listOf str;
              default = ["0.0.0.0" "::"];
              example = ["127.0.0.1" "::1"];
              description = ''
                Interfaces on which to listen for [XMPP over TLS](https://xmpp.org/extensions/xep-0368.html) server-to-server connections.
                Defaults to [default interfaces](https://prosody.im/doc/ports#default_interfaces). Available starting with [0.12.0](https://prosody.im/doc/release/0.12.0).
              '';
            };

            # ────────────────────────────────────────────────────────────────────────
            # HTTP AND HTTPS
            # ────────────────────────────────────────────────────────────────────────

            # ----------------
            # SERVER-TO-SERVER
            # ----------------
            s2s_secure_auth = mkOption {
              type = bool;
              default = true;
              description = ''
                Require valid certificates for server-to-server connections.
                For more information see <https://prosody.im/doc/s2s#security>.
              '';
            };

            s2s_insecure_domains = mkOption {
              type = listOf str;
              default = [];
              example = ["insecure.example"];
              description = ''
                Some servers have invalid or self-signed certificates. You can list
                remote domains here that will not be required to authenticate using
                certificates. They will be authenticated using other methods instead,
                even when s2s_secure_auth (TODO: Reference option if possible.) is enabled.
              '';
            };

            s2s_secure_domains = mkOption {
              type = listOf str;
              default = [];
              example = ["jabber.org"];
              description = ''
                Even if you leave s2s_secure_auth disabled, you can still require valid
                certificates for some domains by specifying a list here.
              '';
            };

            # --------------------------------
            # ENCRYPTION AND SECURITY SETTINGS
            # --------------------------------

            # Other encryption options

            tls_profile = mkOption {
              type = enum [
                "modern"
                "intermediate"
                "old"
                "legacy"
              ];
              default = "intermediate";
              description = ''
                Configures ciphers per corresponding profile from [Mozilla](https://wiki.mozilla.org/Security/Server_Side_TLS)
              '';
            };

            c2s_require_encryption = mkOption {
              type = bool;
              default = true;
              description = ''
                This will force encryption for client to server connections.
              '';
            };

            s2s_require_encryption = mkOption {
              type = bool;
              default = true;
              description = ''
                This will force encryption for server to server connections.
                Note that this does not enforce the use of certificates for authentication (which is required to be truly secure). For more info see our documentation on [s2s security](https://prosody.im/doc/s2s#security).
              '';
            };

            # ---------------------
            # Virtual Host Settings
            # ---------------------
            virtual_host = mkOption {
              type = attrsOf (submodule {
                options = {
                  inherit (host) modules_enabled modules_disabled;

                  enabled = mkOption {
                    type = bool;
                    default = true;
                    description = ''
                      Specifies whether this host is enabled or not.
                      Disabled hosts are not loaded and do not accept connections while Prosody is running.
                    '';
                  };
                };
              });
              default = {};
              example = {
                "localhost" = {
                  modules_enabled = ["bosh"];
                  ssl.cert = "/etc/prosody/certs/example.org.pem";
                  ssl.key = "/etc/prosody/certs/example.org.key";
                };
              };
            };

            # ----------------------
            # Sessions and resources
            # ----------------------
            conflict_resolve = mkOption {
              type = enum [
                "random"
                "increment"
                "kick_new"
                "kick_old"
              ];
              default = "kick_old";
              description = ''
                How to resolve resource conflicts. May be “random” (assign a random resource), “increment” (append a unique integer to the resource),
                “kick_new” (deny the new connection), “kick_old” (disconnect the existing session).
              '';
            };

            ignore_presence_priority = mkOption {
              type = bool;
              default = false;

              description = ''
                When set to true, Prosody will ignore the priority set by the client when routing messages.
                In effect any incoming messages to the user’s bare JID will be broadcast to all of the user’s connected resources instead of the one(s) with the highest priority.
              '';
            };
          }
          modules.mod_register
        ];

      # TODO: Remove
      configFile = mkOption {
        type = path;
        description = ''
          Configuration file.
        '';
      };

      user = mkOption {
        type = str;
        default = "prosody";
        description = ''
          User account under which prosody runs.

          ::: {.note}
          If left as the default value this user will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the prosody service starts.
          :::
        '';
      };

      group = mkOption {
        type = str;
        default = "prosody";
        description = ''
          Group account under which prosody runs.

          ::: {.note}
          If left as the default value this group will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the group exists before the prosody service starts.
          :::
        '';
      };

      checkConfig = mkOption {
        type = bool;
        default = true;
        example = false;
        description = "Check the configuration file with `prosodyctl check config`";
      };

      checkXEP0423 = mkOption {
        type = bool;
        default = true;
        description = ''
          The XEP-0423 defines a set of recommended XEPs to implement
          for a server. It's generally a good idea to implement this
          set of extensions if you want to provide your users with a
          good XMPP experience.

          This NixOS module aims to provide a "advanced server"
          experience as per defined in the XEP-0423[1] specification.

          Setting this option to true will prevent you from building a
          NixOS configuration which won't comply with this standard.
          You can explicitly decide to ignore this standard if you
          know what you are doing by setting this option to false.

          [1] https://xmpp.org/extensions/xep-0423.html
        '';
      };
    };
  };

  config = let
    inherit (lib.meta) getExe;
    inherit (lib.modules) mkIf mkMerge;
  in
    mkIf cfg.enable (mkMerge [
      {
        assertions = [
          # {
          #   assertion = !cfg.checkXEP0423 || (builtins.length cfg.settings.muc > 0);
          #   message = ''
          #       You need to setup at least one MUC domain to comply with XEP-0423.
          #   '';
          # }
          # {
          #   assertion = !cfg.checkXEP0423 || cfg.settings.http_file_share != null;
          #   message = ''
          #     You need to setup http_file_share modules through config.services.prosody.settings.http_file_share to comply with XEP-0423.
          #   '';
          # }
        ];

        # warnings = mkIf !cfg.settings.s2s_secure_auth && !(builtins.elem cfg.settings.modules_enabled "dialback") [
        #   ''
        #     You do not require valid certificates for server-to-server connections. Other methods,
        #     such as other methods such as dialback (DNS) may be used instead. You can enable
        #     dialback in modules_enabled. TODO: How to reference option inside option description?
        #   ''
        # ];
      }
      {
        environment.systemPackages = [cfg.package];

        environment.etc."prosody/prosody.cfg.lua".source =
          if cfg.checkConfig
          then
            pkgs.runCommandLocal "prosody.cfg.lua"
            {
              nativeBuildInputs = [cfg.package];
            }
            ''
              cp ${cfg.configFile} prosody.cfg.lua

              # Replace the hardcoded path to cacerts with one that is accessible in the build sandbox
              sed 's|/etc/ssl/certs/ca-bundle.crt|${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt|' -i prosody.cfg.lua

              # For some reason prosody hard fails to "find" certificates when this directory does not exist
              mkdir certs

              prosodyctl --config ./prosody.cfg.lua check config

              cp prosody.cfg.lua $out
            ''
          else cfg.configFile;

        users = {
          users.${options.services.prosody.user.default} = mkIf (cfg.user == options.services.prosody.user.default) {
            home = cfg.settings.data_path;
            inherit (cfg) group;
            uid = config.ids.uids.prosody;
          };
          groups.${options.services.prosody.group.default} = mkIf (cfg.group == options.services.prosody.group.default) {
            gid = config.ids.gids.prosody;
          };
        };
      }
      {
        systemd.services.prosody = {
          description = "Prosody";

          after = ["network-online.target"];
          restartTriggers = [
            config.environment.etc."prosody/prosody.cfg.lua".source
          ];

          environment = {
            PROSODY_CONFIG = "/run/prosody/prosody.cfg.lua";
          };

          serviceConfig = {
            Group = cfg.group;
            User = cfg.user;

            Type = "simple";

            RuntimeDirectory = "prosody";
            PIDFile = "/run/prosody/prosody.pid";
            ExecStart = "${getExe cfg.package} -F";
            ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
            Restart = "on-abnormal";

            AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];

            MemoryDenyWriteExecute = true;
            PrivateDevices = true;
            PrivateMounts = true;
            PrivateTmp = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;

            StateDirectory = "prosody";
          };

          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
        };
      }
    ]);

  meta.doc = ./prosody.md;
}
