_: {
  environment.persistence = {
    "/state".directories = [
      "/var/lib/iwd"
    ];
  };

  networking.wireless = {
    iwd = {
      enable = true;

      settings = {
        General = {
          AddressRandomization = "network";
        };
      };
    };
  };
}
