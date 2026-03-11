_: super: let
  ngx_http_geoip2_module = super.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "ngx_http_geoip2_module";
    version = "3.4";

    src = super.fetchFromGitHub {
      owner = "leev";
      repo = finalAttrs.pname;
      tag = finalAttrs.version;
      hash = "sha256-CAs1JZsHY7RymSBYbumC2BENsXtZP3p4ljH5QKwz5yg=";
    };

    installPhase = ''
      mkdir $out
      cp *.c config $out/
    '';
  });
in {
  nginx = super.nginx.overrideAttrs (old: {
    configureFlags = old.configureFlags ++ ["--add-module=${ngx_http_geoip2_module}"];
    buildInputs = old.buildInputs ++ [super.libmaxminddb];
  });
}
