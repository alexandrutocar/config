{
  config,
  pkgs,
  ...
}: {
  services.networkd-dispatcher = {
    enable = true;

    rules = {
      vpn-on-demand = {
        onState = ["routable" "carrier"];
        script = let
          internet-ipv4-only-networks = [
            "eduroam"
            "eduroam-cs"
            "eduroam-math"
            "eduroam-stw"
            "eduroam-ukb"
          ];
        in ''
          #!${pkgs.runtimeShell}
          if [[ "$IFACE" == wlan0 ]]; then
            if [[ "$ESSID" == "Specht" ]]; then
              networkctl down ${config.systemd.network.netdevs."25-wg-intra-ipv4".netdevConfig.Name}
              networkctl up ${config.systemd.network.netdevs."25-wg-intra-ipv6".netdevConfig.Name}
              networkctl down ${config.systemd.network.netdevs."25-wg-inter-ipv4".netdevConfig.Name}
              networkctl down ${config.systemd.network.netdevs."25-wg-inter-ipv6".netdevConfig.Name}
            elif ${
            if builtins.length internet-ipv4-only-networks > 0
            then builtins.concatStringsSep " || " (map (name: "[[ \"$ESSID\" ==  \"${name}\" ]]") internet-ipv4-only-networks)
            else "false"
          }; then
              networkctl down ${config.systemd.network.netdevs."25-wg-intra-ipv4".netdevConfig.Name}
              networkctl down ${config.systemd.network.netdevs."25-wg-intra-ipv6".netdevConfig.Name}
              networkctl up ${config.systemd.network.netdevs."25-wg-inter-ipv4".netdevConfig.Name}
              networkctl down ${config.systemd.network.netdevs."25-wg-inter-ipv6".netdevConfig.Name}
            else
              networkctl down ${config.systemd.network.netdevs."25-wg-intra-ipv4".netdevConfig.Name}
              networkctl down ${config.systemd.network.netdevs."25-wg-intra-ipv6".netdevConfig.Name}
              networkctl down ${config.systemd.network.netdevs."25-wg-inter-ipv4".netdevConfig.Name}
              networkctl up ${config.systemd.network.netdevs."25-wg-inter-ipv6".netdevConfig.Name}
            fi
          fi
        '';
      };
    };
  };
}
