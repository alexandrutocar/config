final: super: {
  mkHost = domain: port: "${domain}:${builtins.toString port}";

  ipv6 = {
    enclose = address: "[" + address + "]";
  };
}
