{lib, ...} @ args: {
  config = let
    inherit (lib.attrsets) hasAttr;
    inherit (lib.modules) mkDefault mkIf;
  in
    mkIf (hasAttr "hostName" args) {
      networking = {
        hostName = mkDefault args.hostName;
      };
    };
}
