{pkgs, ...}: {
  home.packages = with pkgs; [
    gpgme
  ];

  programs.thunderbird = {
    enable = true;

    profiles = {
      alex = {
        isDefault = true;

        settings = {
          "mail.openpgp.fetch_pubkeys_from_gnupg" = true;
          "mail.openpgp.allow_external_gnupg" = true;
          "mail.openpgp.remind_encryption_possible" = true;
        };
      };
    };
  };
}
