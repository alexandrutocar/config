# spell-checker: ignore PMTUD daddr dport iifname inet nftables saddr
{config, ...}: let
  inherit (config.shared.virtual-private-networks) ike-ipsec;
in {
  networking = {
    firewall = {
      allowedUDPPorts = [
        500 # IKEv2
      ];
    };

    nftables = {
      tables = {
        "strongswan" = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority filter; policy drop;

              iifname "lo" accept
              ct state { established, related } accept
              ct state invalid drop

              # ICMPv6 is load-bearing on IPv6: ND, PMTUD, DPD-adjacent errors
              meta l4proto ipv6-icmp accept
              ip protocol icmp accept

              # carried over from the firewall this table replaces
              tcp dport 22 accept

              # IKE + NAT-T, and native ESP for peers not behind NAT
              udp dport { 500, 4500 } accept
              meta l4proto esp accept

              # VPN-internal DNS: only mesh sources, only the anchor address
              ip6 saddr ${ike-ipsec.prefix} ip6 daddr ${ike-ipsec.mkAddr ike-ipsec.anchor} meta l4proto { tcp, udp } th dport 53 accept
            }

            chain forward {
              type filter hook forward priority filter; policy drop;

              ct state { established, related } accept

              # the hairpin that makes everyone-talks-to-everyone work:
              # decrypted spoke traffic re-enters toward another spoke's SA
              ip6 saddr ${ike-ipsec.prefix} ip6 daddr ${ike-ipsec.prefix} accept
            }
          '';
        };
      };
    };
  };
}
