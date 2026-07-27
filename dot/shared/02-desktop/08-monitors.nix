_: {
  services.kanshi = {
    enable = true;

    settings = [
      {
        output = {
          criteria = "eDP-1";
          alias = "INTERNAL";
        };
      }

      {
        output = {
          criteria = "Dell Inc. DELL UP2716D *";
          alias = "SCHOOL";
        };
      }
      {
        output = {
          criteria = "Samsung Display Corp. UV3342C *";
          alias = "HOME";
        };
      }
      {
        profile = {
          name = "standard";
          outputs = [
            {
              criteria = "$INTERNAL";
              status = "enable";
            }
          ];
        };
      }
      {
        profile = {
          name = "school";
          outputs = [
            {
              criteria = "$INTERNAL";
            }
            {
              criteria = "$SCHOOL";
              position = "0,-1440";
            }
          ];
        };
      }
      {
        profile = {
          name = "school";
          outputs = [
            {
              criteria = "$INTERNAL";
            }
            {
              criteria = "$SCHOOL";
              position = "-1920,0";
            }
          ];
        };
      }
    ];
  };
}
