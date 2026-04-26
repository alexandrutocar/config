{container, ...}: {
  services.prometheus.exporters.nginx = let
    inherit (container.self) localAddress;
  in {
    enable = true;
    port = 9090;
    listenAddress = localAddress;
  };
}
