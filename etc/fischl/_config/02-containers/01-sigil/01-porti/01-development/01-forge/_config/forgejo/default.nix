_: {
  services = {
    forgejo = {
      enable = true;

      settings = {
        api = {
          ENABLE_SWAGGER = false;
        };

        other = {
          SHOW_FOOTER_VERSION = false;
          SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
          SHOW_FOOTER_POWERED_BY = false;
        };

        oauth2 = {
          # Forgejo as OAuth2 Provider
          ENABLED = false;
        };

        actions = {
          # Forgejo Actions
          ENABLED = true;
        };
      };
    };
  };
}
