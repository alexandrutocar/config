_: {
  # TODO
  # On-site there are 1GB HDD storage available. Backups are run every day between 00:00 and 06:00.
  # /archive/ -> /backups/aether/archive/
  # /var/lib/git -> /backups/aether/var/lib/git/
  # services.restic.backups = {
  #   archive = {
  #     timerConfig = {
  #       OnCalendar = "daily";
  #       Persistent = true;
  #     };
  #     repository = "sftp:u542221-sub1.your-storagebox.de:/home/backups/aether/archive";
  #     paths = [
  #       "/archive"
  #     ];
  #     extraOptions = [
  #       "--compression max"
  #     ];
  #     passwordFile = "/state/secrets/br_1_archive.pwd.txt"
  #   };
  # };

  # services.restic.backups = {
  #   archive = {
  #     pruneOptions = [
  #       "--keep-daily 12"
  #       "--keep-weekly 12"
  #       "--keep-monthly 12"
  #     ];
  #     timerConfig = {
  #       OnCalendar = "daily";
  #       Persistent = true;
  #     };
  #     repository = "sftp:u542221@u542221.your-storagebox.de:/home/backups/aether/archive";
  #     paths = [
  #       "/archive"
  #     ];
  #     extraOptions = [
  #       "--compression max"
  #     ];
  #     passwordFile = "/state/secrets/br_1_archive.pwd.txt"
  #   };
  # };
}
