# ────────────────────────────────────────────────────────────────────────
#
# ▄▀█ █▀█ █▀█ █▀▀ ▄▀█ █▀█ ▄▀█ █▄░█ █▀▀ █▀▀
# █▀█ █▀▀ █▀▀ ██▄ █▀█ █▀▄ █▀█ █░▀█ █▄▄ ██▄
#
# language time fonts...
#
# ────────────────────────────────────────────────────────────────────────
_: {
  # SYSTEM TIME
  # -----------
  time.timeZone = "Europe/Berlin";

  # SYSTEM LOCALE
  # -------------
  i18n = {
    defaultLocale = "de_DE.UTF-8";
    extraLocales = [
      # International
      "en_US.UTF-8/UTF-8"
      # East-Europe
      "ru_RU.UTF-8/UTF-8"
      "uk_UA.UTF-8/UTF-8"
      # East-Asia
      "zh_CN.UTF-8/UTF-8"
      "zh_SG.UTF-8/UTF-8"
      "zh_TW.UTF-8/UTF-8"
    ];
  };
}
