{config, ...}: {
  # imports = [
  #   (builtins.fetchTarball {
  #     url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/master/nixos-mailserver-master.tar.gz";
  #     sha256 = "1wmj512iqf2xlzv2h26mlsqwwphwn529a1awvdm72whyncp34bzb";
  #   })
  # ];

  # security.acme = {
  #   acceptTerms = true;
  #   defaults.email = "security@ueuie.dev";
  # };

  # networking.firewall.allowedTCPPorts = [ 80 ];

  # services.nginx.virtualHosts.${config.mailserver.fqdn}.enableACME = true;

  # mailserver = {
  #   enable = true;
    
  #   stateVersion = 3;

  #   fqdn = "ueuie.dev";
  #   domains = [ "ueuie.dev" ];

  #   # Reference the existing ACME configuration created by nginx
  #   x509.useACMEHost = config.mailserver.fqdn;

  #   loginAccounts = {
  #     "alex@ueuie.dev" = {
  #       hashedPasswordFile = "/etc/accounts/alex/password.txt";

  #       # Additional addresses delivered to this mailbox
  #       aliases = [ "security@ueuie.dev" ];
  #     };
  #   };
  # };
}