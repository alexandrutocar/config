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
        FBQliBiiQM2QC86GLbXHuSAAAAABAAAADAAAABAAAACgLJ2WCrhz6QCvPDgAAAAAAAAAAAAAAAALAAE
        A0AAAACAAAAAAfgAgqpofv014wzyF80bW+6KZp1hZfNayv4QI73liLd2hqX0AEI5jbT5/2VWf8XTVRP
        YCKJucrTPwrzKu3Bwm4VbKWCN9PXTvByY8B5z7SU/YFu6bbZQPQ5v2Viqp6tPh8rMaC/uPbz20O0Dsi
        IcalyrKO8qsfhfZIHhnlFk3ygBOAAgACwAABBIAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAABAAIIyfs9v14efIDy90/pU+dX9OHanM+NuPYmfQLFfihMsKAAAAAAAAAAAAAAAAAAAAAAAAAAA
        AAAAAAAAAAAAAAAAAAAAASAEAAIEAAAEAIgALASQ1BMSD7vIhQl8MtmelwJPcMZQUInWq4hEtnVSprp
        QAAAABARoAAQALAAMEcgAAAAYAgABDABAIAAAAAAABAMvXMc25smsTteFWy80sRGxuGKY3OmUg8iwf2
        s1HQj73ZfXjxhmOSqdVXvG4aQV+iRo3kBpGjtbp0FbPbzCZfsWhCJ3c4Bn+Qy6YSBBnzfgQfwFQC6VI
        Aevsu3dRs5FDDxsd9/ywHQAi6zYKxhilwoJ910qORlzBPX1q3Ig4p2YnmI9ipqLz5FTl6TIvWeRqCuK
        28Or1JzLaWf7gMz6hDUsNhP/a6OaIAUWvX9wgVqh8QqcdMh/NVn4lnTGcab3AmNO/xnHR87MivGpv2V
        lJe7t6/KJ3u7fi7zDfSZq8fRmH71oMXr4eDMpHmfOn2i3c1dZ+Vonj07qceiFh7X2tjHsAAAAA0dChX
        rqJkfCBYOOZ5WWxsHCPBmfLaLJEyVl26pIs86Un9H46hpM5Su6b+jr9jzle6fszb9zVtbiwYxZoUP1r
        jG1HVlysgxXydB7ytvVaYeDJZsHX+lNTTRpgyZx81jecFiYF8BI=
      '';
    };
  };
}
