{lib, ...}: let
  inherit (lib.alias) radii;
in {
  services = {
    radii = {
      enable = true;

      settings = {
        inherit (radii) site;
      };

      # systemd-creds encrypt --with-key=host+tpm2 --name=radii.private-key radii.key -
      privateKey = ''
        FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAABdoEQgcVgciEXBQKcAAAAAAAAAAAAAAAALAAE
        A8AAAACAAAAAAngAgzo4SoorpmnvbD74gHqFn1oYA/F5gXSlQIVX/z+H4BAkAEOHIzMbGvZECJJM3G+
        orkLDO6j7XY3zwQPuqaRuWmjTFpqbhyd9Fk85x+uiGHlPUnFioKZdxa+IKkTvmmtnfHF5NbfOg3kyVB
        VwkvGvWkT+ehn1GX958SUdi9Yp3zxQ4Ux4IDVRosis96mXvf68uSNWClqMywA0jLNQSAE4ACAALAAAE
        EgAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAg2hCvg3Tlajhf/O80SOgHgrCh0Fo
        Fg7lbLwe7T6Y0uvIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIAQAAgQAAAQAiAA
        vuAJGu9FG/Eb+WYnnVLQXm3zjWOfik0jijrtS8Ce3x5QAAAAEBGgABAAsAAwRyAAAABgCAAEMAEAgAA
        AAAAAEA1Q9Nxt85tUmGkPRycTFNNg4hKxomyu6kSN5zdOjY7ayDd6VguqHOJlGF4ehVVB7rmLqjWK5H
        zBU5rG+Y7/V9nJ+7GH2WyQ9Jsz5XNw0wRW4Q5vqUPw5Lp5Sw2zXfKjHQNe7DpkGc9CPMJmSUAlKuCWs
        HJPbGKI+gAYMxLO3Lkx/0J2Bej8AT1Ig4pZTtlIUw7IG4sF7WyoUQjI4GHoeepVkOuz+NBHEyRFd5B0
        +1s+JqDguP/+1hbE8lDXglH1xGZQtzmmjZTO/CzyyTw4It8JbnO11EkRXT69+xE2gB1WfWhP3EGWmVO
        4ue3atJ+wGSP+CnysQh6gpLM9qT0tOAHQAAAAB6EqK4/eYTlkvGbR4fHvsZSlGP1vN1CEGMYgqOZrBN
        HfvcoZT0K5u+uBFuM0tZSsuBAUpHBN1Vy7l1WZPDT4I0ao2/SuYh1jzHrZjthvaSGfTOwB8PnVFDe7Y
        6kf3PCx+jqOC3AQ==
      '';
    };
  };
}
