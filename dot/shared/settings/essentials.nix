# ────────────────────────────────────────────────────────────────────────
#
# █▀▀ █▀ █▀ █▀▀ █▄░█ ▀█▀ █ ▄▀█ █░░ █▀
# ██▄ ▄█ ▄█ ██▄ █░▀█ ░█░ █ █▀█ █▄▄ ▄█
#
# applications, fonts...
#
# ────────────────────────────────────────────────────────────────────────
{pkgs, ...}: {
  home.packages = with pkgs; [
    # PDF/EPUB READER
    # ---------------
    zathura

    # MARKDOWN READER
    # ---------------
    glow
  ];

  # GNU PRIVACY GUARD
  # -----------------
  programs.gpg = {
    # ────────────────────────────────────────────────────────────────────────
    # TODO: Reconfigure for new keyset (modified before 21.11.2024 16:59)
    # ────────────────────────────────────────────────────────────────────────
    settings = {
      # General
      no-greeting = true; # disable the greeting message
      no-emit-version = true; # do not emit the version
      no-comments = true; # do not write comments in clear text signatures

      # Display
      display-charset = "utf-8";

      # Server
      keyserver = "hkp://keys.openpgp.org";
      auto-key-locate = "wkd,dane,local";

      # Export
      export-options = "export-minimal"; # export minimal information
      keyid-format = "0xlong"; # use long key ids
      with-fingerprint = true; # include key fingerprints in key listings
      with-keygrip = true; # include key grip in key listings

      # List/Verify
      list-options = "show-uid-validity"; # show the validity of users
      verify-options = "show-uid-validity show-keyserver-urls"; # show the validity of users and keyservers

      # Cipher/Digest
      personal-cipher-preferences = "AES256";
      personal-digest-preferences = "SHA512";
      personal-compress-preferences = ["BZIP2 ZLIB ZIP Uncompressed"];
      default-preference-list = "SHA512 SHA384 SHA256 RIPEMD160 AES256 TWOFISH BLOWFISH ZLIB BZIP2 ZIP Uncompressed";
      cipher-algo = "AES256";
      digest-algo = "SHA512";
      cert-digest-algo = "SHA512";
      compress-algo = "ZLIB";

      # Precaution
      disable-cipher-algo = "3DES"; # Disable 3DES
      weak-digest = "SHA1"; # Disable SHA1
      throw-keyids = true; # Disable recipient key ID in messages (WARNING: breaks Mailvelope)
      armor = true; # Output ASCII instead of binary
      require-secmem = true; # Enforce memory locking to avoid accidentally swapping GPG memory to disk
      no-symkey-cache = true; # Disable caching of passphrase for symmetrical ops
      require-cross-certification = true;

      # Agent
      use-agent = true; # Enable SmartCard

      # String-to-key (S2K) settings
      s2k-cipher-algo = "AES256"; # Set the S2K cipher algorithm
      s2k-digest-algo = "SHA512"; # Set the S2K digest algorithm
      s2k-mode = "3"; # Set the S2K mode
      s2k-count = "65011712"; # Set the S2K count
    };
  };

  # DISPLAY RULES
  # -------------
  wayland.windowManager.river.settings = {
    rule-add."-app-id" = {
      # Zathura
      "'org.pwmt.zathura'" = ["ssd" "float"];
    };
  };
}
