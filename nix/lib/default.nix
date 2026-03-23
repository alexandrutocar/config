final: super: {
  extra = {
    attrsets = import ./extra/attrsets.nix final super;
    strings = import ./extra/strings.nix final super;
    colors = import ./extra/colors.nix final super;
    files = import ./extra/files.nix final super;
    math = import ./extra/math/default.nix final super;
    net = import ./extra/net.nix final super;
    
    types = import ./extra/types/default.nix final super;

    systemd = import ./extra/systemd.nix final super;
  };
}
