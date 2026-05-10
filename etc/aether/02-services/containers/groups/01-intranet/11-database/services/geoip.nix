_: {
  # systemd.timers.geoip = {
  #   description = "GeoIP Updater Timer";

  #   partOf = [ "geoip.service" ];
  #   wantedBy = [ "timers.target" ];

  #   timerConfig = {
  #     OnCalendar = "weekly";
  #     Persistent = "true";
  #     RandomizedDelaySec = "3600";
  #   };
  # };

  # systemd.services.geoip = {
  #   description = "GeoIP Updater";
  #   after = [ "network-online.target" "nss-lookup.target" ];
  #   wants = [ "network-online.target" ];
  #   preStart = ''
  #     mkdir -p "/var/lib/geoip"
  #     chmod 755 "/var/lib/geoip"
  #     chown geoip:srv "/var/lib/geoip"
  #   '';
  #   serviceConfig = {
  #     User = "geoip";
  #     PermissionsStartOnly = true;
  #   };
  # };
}
