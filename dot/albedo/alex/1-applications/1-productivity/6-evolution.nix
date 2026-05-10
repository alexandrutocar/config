_: {
  wayland.windowManager.river.settings = {
    rule-add = {
      "-app-id"."'org.gnome.Evolution'" = {
        "-title" = {
          "'*'" = "float";
          "'Eingang*'" = ["no-float"];
          "'Kontakte'" = ["no-float"];
          "'Kalendar'" = ["no-float"];
          "'Aufgaben'" = ["no-float"];
          "'Notizen'" = ["no-float"];
        };
      };

      "-app-id"."'evolution-alarm-notify'" = {
        "-title" = {
          "'*'" = ["float"];
        };
      };
    };
  };
}
