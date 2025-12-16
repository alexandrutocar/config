# Emergency

## A file in `/state` has been deleted...

In such cases reverting to previous generation is not always an option, as it too likely depends on the file being present at the expected location.

If it ever happens:

1. You will be presented with an emergency access shell.
  - Log-in using emergency access password.
2. Depending on which file is missing, you may either have to mount and
   unlock the disk manually (ZFS) or be presented with already unlocked
   disk.
3. Debug the failing service using `systemctl`.
4. Put the missing file where it belongs under `/state`.
5. Reboot.

## More:

- <https://phip1611.de/blog/i-switched-to-another-nixos-configuration-and-deleted-my-main-user>
