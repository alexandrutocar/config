# spell-checker: ignore credstore
_: {
  environment.persistence = {
    "/state" = {
      directories = [
        "/etc/credstore.encrypted"
        "/etc/credstore"
      ];
    };
  };
}
