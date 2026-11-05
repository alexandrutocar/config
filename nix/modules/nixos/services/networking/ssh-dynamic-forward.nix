{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.ssh-dynamic-forward;
in {
  options = let
    inherit (lib.attrsets) mapAttrs optionalAttrs;
    inherit (lib.modules) mkDefault;
    inherit (lib.options) literalExpression mkEnableOption mkOption mkPackageOption;
    inherit (lib.types) attrsOf bool either int lines listOf nullOr oneOf port str submodule;
    inherit (lib.strings) hasInfix;
  in {
    services.ssh-dynamic-forward = {
      package = mkPackageOption pkgs "openssh" {};

      tunnels = mkOption {
        type = attrsOf (submodule ({
          name,
          config,
          ...
        }: {
          options = {
            enable = mkEnableOption "this SOCKS tunnel" // {default = true;};

            serviceName = mkOption {
              type = str;
              readOnly = true;
              defaultText = literalExpression ''"ssh-dynamic-forward@''${name}.service"'';
              example = literalExpression ''
                {
                  systemd.services.my-app = {
                    wants = [ config.services.ssh-dynamic-forward.tunnels.work.serviceName ];
                    after = [ config.services.ssh-dynamic-forward.tunnels.work.serviceName ];
                  };
                }
              '';
              description = ''
                Full systemd unit name of this tunnel's instance, including the
                `.service` suffix. Use it to order or bind other units to the tunnel
                without hard-coding the naming scheme. The unit only exists while
                `enable` is true.
              '';
            };

            hostName = mkOption {
              type = str;
              example = "login.example.org";
              description = "SSH server to tunnel through (ssh_config `HostName`).";
            };

            user = mkOption {
              type = nullOr str;
              default = null;
              description = "Remote login name (ssh_config `User`).";
            };

            port = mkOption {
              type = port;
              default = 22;
              description = "Remote SSH port (ssh_config `Port`).";
            };

            listen = {
              address = mkOption {
                type = str;
                default = "127.0.0.1";
                description = "Local address the SOCKS proxy binds to.";
              };
              port = mkOption {
                type = port;
                default = 1080;
                description = "Local port the SOCKS proxy listens on.";
              };
            };

            knownHosts = mkOption {
              type = lines;
              default = "";
              example = "login.example.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
              description = ''
                Pinned host keys in known_hosts format. Written to the Nix store and
                used as `UserKnownHostsFile`. Leave empty to set it via `settings`.
              '';
            };

            openFirewall = mkOption {
              type = bool;
              default = false;
              description = "Open `listen.port` in the firewall (only useful with a non-loopback `listen.address`).";
            };

            settings = mkOption {
              type = let
                atom = oneOf [bool int str];
              in
                attrsOf (nullOr (either atom (listOf atom)));
              default = {};
              example = literalExpression ''
                {
                  IdentityFile = "%d/id_ed25519";
                  ServerAliveInterval = 15;
                  Compression = true;
                  LocalForward = [ "8080 intranet:80" ];
                }
              '';
              description = ''
                ssh_config(5) options for this tunnel's `Host` block. Booleans render
                as yes/no, lists as repeated keywords, null drops a keyword.
                Use canonical capitalisation so your values replace the defaults.
              '';
            };
          };

          config = let
            formatListen = address: port: let
              addr =
                if hasInfix ":" address
                then "[${address}]"
                else address;
            in "${addr}:${toString port}";
          in {
            # Set as a definition (not a default) so readOnly rejects any user
            # override - same approach as systemd.services.<name>.name.
            serviceName = "ssh-dynamic-forward@${name}.service";

            settings = mapAttrs (_: mkDefault) (
              {
                HostName = config.hostName;
                Port = config.port;
                DynamicForward = formatListen config.listen.address config.listen.port;
                SessionType = "none"; # == ssh -N

                BatchMode = true;
                ConnectTimeout = 10;
                ExitOnForwardFailure = true;
                IdentitiesOnly = true;
                PreferredAuthentications = "publickey";
                ServerAliveCountMax = 3;
                ServerAliveInterval = 30;
                StrictHostKeyChecking = true;
                UpdateHostKeys = false;
              }
              // optionalAttrs (config.user != null) {User = config.user;}
              // optionalAttrs (config.knownHosts != "") {
                UserKnownHostsFile = "${pkgs.writeText "ssh-dynamic-forward-${name}-known_hosts" config.knownHosts}";
              }
            );
          };
        }));
        default = {};
        description = ''
          Persistent SSH dynamic port forwards (SOCKS4/5 proxies). Each attribute
          becomes the systemd template instance `ssh-dynamic-forward@<name>.service`.
          Names must match `[A-Za-z0-9_][A-Za-z0-9_.-]*`.
        '';
      };
    };
  };

  config = let
    inherit (lib.attrsets) filterAttrs mapAttrs' mapAttrsToList mergeAttrsList nameValuePair;
    inherit (lib.lists) concatLists toList;
    inherit (lib.meta) getExe';
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.strings) concatLines removeSuffix;
    inherit (lib.trivial) boolToYesNo;
  in let
    enabledTunnels = filterAttrs (_: t: t.enable) cfg.tunnels;
  in
    mkIf (enabledTunnels != {}) (mkMerge [
      {
        assertions =
          mapAttrsToList (name: _: {
            assertion = builtins.match "[A-Za-z0-9_][A-Za-z0-9_.-]*" name != null;
            message = ''
              services.ssh-dynamic-forward.tunnels."${name}": tunnel names must match
              [A-Za-z0-9_][A-Za-z0-9_.-]* so they can be used verbatim as a systemd
              instance name and as the ssh_config Host alias.
            '';
          })
          enabledTunnels;
      }
      {
        networking = {
          firewall = {
            allowedTCPPorts =
              mapAttrsToList (_: t: t.listen.port)
              (filterAttrs (_: t: t.openFirewall) enabledTunnels);
          };
        };
      }
      {
        systemd = {
          services = mergeAttrsList [
            {
              "ssh-dynamic-forward@" = {
                description = "SSH dynamic forward (SOCKS) '%i'";
                wants = ["network-online.target"];
                after = ["network-online.target"];
                startLimitIntervalSec = 0; # never give up reconnecting

                serviceConfig = {
                  # ${SSH_DYNAMIC_FORWARD_CONFIG} always expands to exactly one argument.
                  ExecStart = "${getExe' cfg.package "ssh"} -F \${SSH_DYNAMIC_FORWARD_CONFIG} %i";
                  Restart = "always";
                  RestartSec = 10;

                  DynamicUser = true;
                  UMask = "0077";

                  CapabilityBoundingSet = "";
                  LockPersonality = true;
                  MemoryDenyWriteExecute = true;
                  NoNewPrivileges = true;
                  PrivateDevices = true;
                  ProcSubset = "pid";
                  ProtectClock = true;
                  ProtectControlGroups = true;
                  ProtectHome = true;
                  ProtectHostname = true;
                  ProtectKernelLogs = true;
                  ProtectKernelModules = true;
                  ProtectKernelTunables = true;
                  ProtectProc = "invisible";
                  RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
                  RestrictNamespaces = true;
                  RestrictRealtime = true;
                  RestrictSUIDSGID = true;
                  SystemCallArchitectures = "native";
                  SystemCallFilter = ["@system-service" "~@privileged @resources"];
                };
              };
            }
            (
              mapAttrs' (
                name: tunnel: let
                  renderValue = v:
                    if builtins.isBool v
                    then boolToYesNo v
                    else toString v;

                  # Lists become repeated keywords. null removes a
                  # keyword (e.g. to drop one of the defaults).
                  renderSettings = settings:
                    concatLines (concatLists (mapAttrsToList
                      (key: value: map (v: "  ${key} ${renderValue v}") (toList value))
                      (filterAttrs (_: v: v != null) settings)));
                in
                  # systemd.services keys omit the ".service" suffix.
                  nameValuePair (removeSuffix ".service" tunnel.serviceName) {
                    overrideStrategy = "asDropin";
                    description = "SSH dynamic forward (SOCKS) '${name}' via ${tunnel.hostName}";
                    wantedBy = ["multi-user.target"];
                    environment = let
                      configFile = pkgs.writeText "ssh-dynamic-forward-${name}.conf" ''
                        Host ${name}
                        ${renderSettings tunnel.settings}'';
                    in {
                      SSH_DYNAMIC_FORWARD_CONFIG = "${configFile}";
                    };
                  }
              )
              enabledTunnels
            )
          ];
        };
      }
    ]);
}
