_: {
  programs.tofi = {
    enable = true;

    settings = {
      font = "Tamsyn";

      font-size = 15;

      text-color = "#AAAAAA";

      prompt-color = "#FFFFFF";

      selection-color = "#AAAAAA";

      selection-match-color = "#FFFFFF";

      prompt-text = "Run:";

      prompt-padding = 17;

      result-spacing = 17;

      horizontal = true;

      min-input-width = 300;

      width = "68%";

      height = 55;

      background-color = "#000000";

      outline-width = 0;

      border-width = 1;

      border-color = "#AAAAAA";

      clip-to-padding = false;

      padding-top = 17;

      padding-left = 17;

      require-match = false;

      hide-input = false;

      terminal = "foot";
    };
  };

  xdg.desktopEntries = {
    reboot = {
      name = "Reboot";
      exec = "systemctl reboot";
      type = "Application";

      categories = ["System"];

      settings = {
        Comment = "Reboot the system";
      };

      terminal = false;
    };

    shutdown = {
      name = "Shutdown";
      exec = "systemctl poweroff";
      type = "Application";

      categories = ["System"];

      settings = {
        Comment = "Power system off";
      };

      terminal = false;
    };

    lock = {
      name = "Lock";
      exec = "locker lock";
      type = "Application";

      categories = ["System"];

      settings = {
        Comment = "Lock the screen";
      };

      terminal = false;
    };
  };
}
