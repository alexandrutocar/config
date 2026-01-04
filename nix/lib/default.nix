final: super: {
  custom = {
    attrsets = import ./custom/attrsets.nix final super;
    strings = import ./custom/strings.nix final super;
    colors = import ./custom/colors.nix final super;
    files = import ./custom/files.nix final super;
    math = import ./custom/math.nix final super;
    net = import ./custom/net.nix final super;
    systemd = import ./custom/systemd.nix final super;

    types = {
      colors = import ./custom/types/colors.nix final super;
    };
  };
}
