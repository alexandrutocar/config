_: {
  services = {
    redis = {
      servers = {
        stalwart = {
          enable = true;

          bind = "::";
        };
      };
    };
  };
}
