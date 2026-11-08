{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  # SYSTEM TIME
  # -----------
  time.timeZone = mkDefault "UTC";

  # SYSTEM LOCALE
  # -------------
  i18n = {
    defaultLocale = mkDefault "C.UTF-8";
  };
}
