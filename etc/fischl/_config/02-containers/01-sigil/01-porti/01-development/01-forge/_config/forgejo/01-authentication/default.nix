_: {
  services = {
    forgejo = {
      settings = {
        service = {
          # Authentication
          # --------------
          ENABLE_BASIC_AUTHENTICATION = false;
          ENABLE_INTERNAL_SIGNIN = false;

          # Anonymous visitors may view public repositories (and read the
          # public API). Everything else still needs a Guard login.
          REQUIRE_SIGNIN_VIEW = false;
          ENABLE_USER_HEATMAP = false;

          # Registration
          # ------------
          #
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          SHOW_REGISTRATION_BUTTON = false;

          # ────────────────────────────────────────────────────────────────────────
          # NOTE: Must stay false, otherwise Guard users can never be created.
          # ────────────────────────────────────────────────────────────────────────
          DISABLE_REGISTRATION = false;

          # User Privacy
          # ------------
          DEFAULT_KEEP_EMAIL_PRIVATE = true;
        };

        "service.explore" = {
          DISABLE_USERS_PAGE = true;
          DISABLE_CODE_PAGE = true;
        };

        openid = {
          # ────────────────────────────────────────────────────────────────────────
          # NOTE: sign-in defaults on, sign-up follows DISABLE_REGISTRATION.
          # ────────────────────────────────────────────────────────────────────────
          ENABLE_OPENID_SIGNIN = false;
          ENABLE_OPENID_SIGNUP = false;
        };

        oauth2_client = {
          ENABLE_AUTO_REGISTRATION = true;
          USERNAME = "preferred_username";
          UPDATE_AVATAR = true;
          ACCOUNT_LINKING = "disabled";
        };

        admin = {
          EXTERNAL_USER_DISABLE_FEATURES = "manage_password";
        };

        security = {
          DISABLE_QUERY_AUTH_TOKEN = true;
          LOGIN_REMEMBER_DAYS = 7;
        };
      };
    };
  };
}
