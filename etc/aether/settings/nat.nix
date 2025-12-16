# ────────────────────────────────────────────────────────────────────────
#
# █▄░█ ▄▀█ ▀█▀
# █░▀█ █▀█ ░█░
#
# nat, network address translation, networking...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  # NETWORK ADDRESS TRANSLATION
  # ---------------------------
  # networking.nftables.tables."nat" = {
  #   family = "nat";
  #   content = ''

  #   '';
  # };

  networking.nat = {
    enable = true;

    externalInterface = "wlan0";
    internalInterfaces = [
      "ve-*"
    ];
  };

  # FIREWALL
  # --------
  # ────────────────────────────────────────────────────────────────────────
  # TODO: Granular permissions
  # ────────────────────────────────────────────────────────────────────────
  # networking.nftables.tables = let
  #   mkInterface = name:
  #     if name == "wan"
  #     then ''"wlan0"''
  #     else ''"ve-${name}"'';
  # in {
  #   containers = {
  #     family = "inet";
  #     content = ''
  #       chain forward {
  #         type filter hook forward priority 0; policy drop;

  #         # Allow response traffic.
  #         ct state established,related accept

  #         # Allow traffic originating from specific
  #         # interfaces, protocols and ports.
  #         # set dns {
  #         #   type ifname . integer . inet_service
  #         #   elements = {
  #         #     ${mkInterface "x0-llm"} . tcp . 853,
  #         #     ${mkInterface "wan"} . tcp . 853
  #         #   }
  #         # }

  #         # set ext {
  #         #   type ifname . integer . inet_service
  #         #   elements = {
  #         #     ${mkInterface "wan"} . tcp . 443,
  #         #   }
  #         # }

  #         iifname ${mkInterface "x0-acm"} oifname ${mkInterface "x0-dns"} tcp dport { 853 } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-acm"} tcp dport { 443 } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-dns"} tcp dport { 853 } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-fin"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-git"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-hit"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-ins"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-llm"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-nbc"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-ext"} oifname ${mkInterface "x0-pim"} tcp dport { 80  } accept
  #         iifname ${mkInterface "x0-llm"} oifname ${mkInterface "x0-dns"} tcp dport { 853 } accept

  #         iifname ${mkInterface "x0-dns"} oifname ${mkInterface "wan"} tcp dport { 443, 53 } accept
  #         iifname ${mkInterface "x0-dns"} oifname ${mkInterface "wan"} udp dport { 53      } accept
  #         iifname ${mkInterface "x0-llm"} oifname ${mkInterface "wan"} tcp dport { 443     } accept

  #         iifname ${mkInterface "wan"} oifname ${mkInterface "x0-dns"} tcp dport { 853          } accept
  #         iifname ${mkInterface "wan"} oifname ${mkInterface "x0-ext"} tcp dport { 443          } accept
  #         iifname ${mkInterface "wan"} oifname ${mkInterface "x0-pim"} tcp dport { 80, 139, 445 } accept
  #       }
  #     '';
  #   };
  # };
}
