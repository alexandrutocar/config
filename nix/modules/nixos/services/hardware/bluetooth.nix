{lib, ...} @ args: {
  config = let
    inherit (lib.attrsets) hasAttr;
    inherit (lib.modules) mkDefault mkIf;
  in
    mkIf (hasAttr "hostName" args) {
      hardware = {
        bluetooth = {
          settings = {
            General = {
              Name = mkDefault args.hostName;
            };
          };
        };
      };
    };
}
