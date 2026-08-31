{dns, ...}: name: zone: {
  inherit name;
  zonefile = toString (dns.util.writeZone name zone);
}
