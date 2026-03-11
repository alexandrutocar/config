# NixOS Configuration for Discord-like XMPP Server
# Features: E2EE (OMEMO), MUC, MAM, File Sharing, Voice/Video ready
#
# Usage: Import this in your configuration.nix or use as a standalone module
# Remember to replace placeholder values (domain, admin email, etc.)
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Required for ACME/Let's Encrypt certificates
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@example.com"; # Change this to your email
  };

  # Prosody XMPP Server
  services.prosody = {
    enable = true;

    # Your domain - change this!
    xmppComplianceSuite = true; # Enable modern XMPP compliance

    # Virtual hosts
    virtualHosts = {
      "chat.example.com" = {
        # Change to your domain
        enabled = true;
        domain = "chat.example.com";

        # SSL/TLS Configuration
        ssl = {
          cert = "/var/lib/acme/chat.example.com/cert.pem";
          key = "/var/lib/acme/chat.example.com/key.pem";
        };
      };
    };

    # Multi-User Chat (MUC) - Discord-like channels
    muc = [
      {
        domain = "conference.chat.example.com"; # Change to your domain
        name = "Chat Rooms";
        restrictRoomCreation = false; # Allow users to create rooms
        maxHistoryMessages = 50; # History sent to new joiners
      }
    ];

    # File upload configuration (for images, files)
    uploadHttp = {
      domain = "upload.chat.example.com"; # Change to your domain
      uploadFileSizeLimit = 104857600; # 100MB
      uploadExpireAfter = 60 * 60 * 24 * 7; # Keep files for 7 days
    };

    # Admin users - change to your JID
    admins = ["admin@chat.example.com"];

    # Enable essential modules
    modules = {
      # Core functionality
      roster = true; # Contact lists
      saslauth = true; # Authentication
      tls = true; # Encryption
      dialback = true; # Server-to-server verification
      disco = true; # Service discovery
      carbons = true; # Message copies to all devices
      csi_simple = true; # Client state indication (mobile battery saving)
      cloud_notify = true; # Push notifications

      # Privacy & Security
      blocklist = true; # User blocking
      privacy = true; # Privacy lists

      # Message features
      mam = true; # Message Archive Management (history)
      offline = true; # Offline message storage

      # User experience
      ping = true; # Keepalive
      register = true; # In-band registration (set to false if invite-only)
      time = true; # Entity time
      uptime = true; # Server uptime
      version = true; # Server version
      admin_adhoc = true; # Admin commands

      # Modern XMPP features
      bookmarks = true; # XEP-0048/0402 - Channel bookmarks
      vcard_legacy = true; # User profiles (legacy)
      vcard4 = true; # User profiles (modern)
      pep = true; # Personal Eventing Protocol (avatars, mood, etc.)

      # HTTP
      http = true; # HTTP server for uploads
      http_files = true; # Serve uploaded files

      # MUC enhancements
      muc_mam = true; # Message history for group chats
    };

    # Extra configuration for advanced features
    extraConfig = ''
      -- Connection limits
      c2s_require_encryption = true  -- Force encryption for clients
      s2s_require_encryption = true  -- Force encryption for server-to-server
      s2s_secure_auth = true         -- Require authenticated server connections

      -- Archive settings (for MAM)
      archive_expires_after = "4w"   -- Keep messages for 4 weeks

      -- MUC specific settings
      Component "conference.chat.example.com" "muc"
        modules_enabled = {
          "muc_mam";           -- Group chat history
          "vcard_muc";         -- Room avatars
        }
        muc_room_locking = false          -- Don't lock rooms by default
        muc_room_lock_timeout = 300       -- Lock timeout
        muc_tombstones = true             -- Track deleted rooms
        muc_room_default_public = true    -- Rooms discoverable by default
        muc_room_default_members_only = false
        muc_room_default_moderated = false
        muc_room_default_persistent = true -- Rooms persist when empty
        muc_room_default_history_length = 20

      -- HTTP Upload settings
      Component "upload.chat.example.com" "http_upload"
        http_upload_file_size_limit = 104857600  -- 100MB
        http_upload_expire_after = 60 * 60 * 24 * 7  -- 7 days
        http_upload_quota = 1073741824  -- 1GB per user

      -- Proxy for file uploads (helps with NAT/firewall)
      Component "proxy.chat.example.com" "proxy65"
        proxy65_address = "chat.example.com"
        proxy65_acl = { "chat.example.com" }

      -- Allow message carbons
      carbons_max_clients = 5

      -- Enable message reactions (XEP-0444)
      -- Note: This requires prosody-modules (community modules)
      -- modules_enabled = { "reactions" }

      -- HTTP settings
      http_default_host = "chat.example.com"
      http_external_url = "https://chat.example.com/"
      https_certificate = "/var/lib/acme/chat.example.com/fullchain.pem"
      https_key = "/var/lib/acme/chat.example.com/key.pem"

      -- Cross-domain settings for web client
      cross_domain_bosh = true
      consider_bosh_secure = true
      cross_domain_websocket = true
      consider_websocket_secure = true
    '';

    # Package selection
    package = pkgs.prosody;
  };

  # Nginx reverse proxy for HTTP uploads and potential web client
  services.nginx = {
    enable = true;

    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts = {
      # Main domain
      "chat.example.com" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://localhost:5280";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };

      # Upload domain
      "upload.chat.example.com" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://localhost:5280";
          extraConfig = ''
            client_max_body_size 100M;
          '';
        };
      };

      # MUC domain (for HTTP queries if needed)
      "conference.chat.example.com" = {
        enableACME = true;
        forceSSL = true;
      };
    };
  };

  # Optional: Jitsi Meet for voice/video channels
  # Uncomment to enable
  # services.jitsi-meet = {
  #   enable = true;
  #   hostName = "meet.chat.example.com";
  #
  #   config = {
  #     enableWelcomePage = true;
  #     prejoinPageEnabled = false;
  #     requireDisplayName = true;
  #   };
  #
  #   # XMPP server integration
  #   prosody.enable = true;
  # };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80 # HTTP (ACME challenges)
      443 # HTTPS
      5222 # XMPP client-to-server
      5269 # XMPP server-to-server
      5280 # HTTP (BOSH/WebSocket)
      5281 # HTTPS (BOSH/WebSocket)
    ];
    allowedUDPPorts = [
      # Uncomment if enabling Jitsi
      # 10000  # Jitsi video bridge
    ];
  };

  # DNS records you need to configure:
  # A     chat.example.com           -> your-server-ip
  # A     conference.chat.example.com -> your-server-ip
  # A     upload.chat.example.com     -> your-server-ip
  # A     proxy.chat.example.com      -> your-server-ip
  # SRV   _xmpp-client._tcp.chat.example.com  -> 5222 chat.example.com
  # SRV   _xmpp-server._tcp.chat.example.com  -> 5269 chat.example.com
  # SRV   _xmpps-client._tcp.chat.example.com -> 5223 chat.example.com (if using direct TLS)
  # TXT   _xmpp-client-xbosh.chat.example.com -> "https://chat.example.com:5281/http-bind"
  # TXT   _xmpp-client-websocket.chat.example.com -> "wss://chat.example.com:5281/xmpp-websocket"

  # Optional: Install community modules for extra features
  # environment.systemPackages = with pkgs; [
  #   # You may need to add prosody-modules manually or via overlay
  # ];

  # Backup recommendation: backup these directories regularly
  # - /var/lib/prosody  (user data, messages if stored)
  # - /var/lib/prosody/http_upload  (uploaded files)
}
