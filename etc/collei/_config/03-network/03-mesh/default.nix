{lib, ...}: let
  inherit (lib.alias) radii;
in {
  services = {
    radii = {
      enable = true;

      settings = {
        inherit (radii) site;
      };

      # systemd-creds encrypt --with-key=host --name=radii.private-key radii.key -
      privateKey = ''
        Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAADrxObRTyqxYHojvj8AAAAA/jI3fJkce9YGeIz
        eEQtud+N33Deoc2sx3to/mXwPHW9a09kY1ssdwnD1pV1MqdzpsQJmSWTAbr+je10Vdox/mVz0xTEa7E
        Qf6YxPMPYex9pjxlygkA+kNFm/QO+ILzxAqomPoWw=
      '';
    };
  };
}
