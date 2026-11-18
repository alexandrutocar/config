{lib, ...}: let
  inherit (lib.alias) radii;
in {
  # (INTERNAL) NETWORK
  # ------------------
  services.radii = {
    enable = true;

    settings = {
      inherit (radii) site;
    };

    # systemd-creds encrypt --with-key=host+tpm2 --name=radii.private-key radii.key -
    privateKey = ''
      FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAABalhHt2qM59BketfMAAAAAAAAAAAAAAAALAAE
      A8AAAACAAAAAAngAgvTJwFWbw6MNIyv9v+fjMSbaoeHliMuVUAWlv1pu6tqMAEHRbt2wtslMzT5Gjm9
      IC+loW5iAExqq1KbtbrSuQLToqGn9EQ45AP0e5X0pbAXUiomIm7KAHtpi7hIrxlIK2Zl/BJflwaEMmX
      G9C1RievX9lafvW+7OcIerspQk7DyDpuH/qZCu7ZvBafk3/9XuFF6fkKEUjlzjIMwSAAE4ACAALAAAE
      EgAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAgtYzwBcmaZdiRGnqpWoVJC9nkE4j
      AjOvAPDkft4X845kAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAQAAgQAAAQAiAA
      vWqgmFDCcUKLAVh0G8IKTzI9LEKpVQ/8aquJ8M0oNgMwAAAAEBGgABAAsAAwRyAAAABgCAAEMAEAgAA
      AAAAAEAmAIKfKg5j37jmIxEzjZpfnMqatbzHZ1GVqCZltjTM8W1k9Oa7uxIGG/uH0+FkWP1l5vl817B
      BqHkd6lrdFR6JBZQd3kiw/Wo6QANh2J0L8+u2UQ1gwHqzOAO+kwHp2jSXpkaniAhUB3r200nWXOSLpq
      AhFSqRuqkb7JKGMPCnCL9/UKcdptl9ycy1g/gaH1UiNyQClFuPwLUQVIOJZE3q/DSs1ra+bON8s8c8J
      nAqvofz7idoV9ciWuQMiMajyZD0Uh7/cfDULJXiS4n7lGzUR3bW2rF3NJw/gecdN/Ak3HyrU7VAggN8
      ru6RC3j6iab8SsXPDwWW+psT/UPtameJQAAAAAeE1MEkTgWaF/TKDTEM3zw6fyjXurRR7HTDZOVbebh
      0EizvRy5Rw3n7SyS+w0YfxhiGtcLYLK9LEltdZv0KK5UK5JvbE20ZNOH8pLtE5lfxaXC6vvQ5gjL4pa
      1o4yOINknAUOskw==
    '';
  };
}
