{
  config,
  lib,
  ...
}: let
  inherit (lib.custom.systemd) mkSetCredentialEncrypted;
in {
  custom.services.backup = {
    enable = true;
    periodic = {
      docs = {
        target = "${config.home.homeDirectory}/03 Dokumente";
        flags = [
          "--compression max"
        ];
      };
      library = {
        target = "${config.home.homeDirectory}/02 Bibliothek";
        flags = [
          "--compression max"
        ];
      };
    };
  };

  systemd.user.timers = {
    ${config.custom.services.backup.periodic.docs.serviceUnitName} = {
      Timer = {
        OnCalendar = "00:05";
        RandomizedDelaySec = "5h";
        Persistent = true;
      };
    };
    ${config.custom.services.backup.periodic.library.serviceUnitName} = {
      Timer = {
        OnCalendar = "00:05";
        RandomizedDelaySec = "5h";
        Persistent = true;
      };
    };
  };

  systemd.user.services = {
    ${config.custom.services.backup.periodic.docs.serviceUnitName} = {
      Service.SetCredentialEncrypted = mkSetCredentialEncrypted {
        aws-access-key-id = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAACbss/iyT7fd/SI9csAAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAguJJfeTBk0aU+rPuTfhktKrwcHleeRS1k8TlXiQcVDZ
          0AEOmm/16pvrdggKokbIK8awRvGKy2c52hAdG00+i6vcBCWm6TVsTRUhv295njTuagOXk
          +BoMO+yzAH+KfGFohzF5EXPfgzMJ7PlQhs4FrONlfQFhVMbGc8hQ4YlIrpWW1+OMmuPxO
          sy1q7o290OWfz8YG20dMRMbBZp4+AE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgwlp4L0fxLk12Wbo5PuyERhhTc6U4eQuI7JwjUjDU0T0AAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAAAs28Vp63J56cEb
          RIPbKpvJtIq55ZnYuOepHTJN/gZUlPCmNJfOysB0haVhYrO57E6kkj7HNLjY+OxW3rWuv
          9aZYmFzvPNNHK0m5KUetop6kzguidIw6lVQ=
        '';
        aws-secret-access-key = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAAAzncrG0dxV7ZKmXw0AAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgYzS6PowlVN3djNYfRBeOLoE65MLSwIK26/AWS0c+cp
          sAEHjcNz+xCJ7jQ81u7SW6ahhqAcYzorGwn8/thH+IIEhB7WKOVTWtLzhi2qSGe1v5WNt
          7aIm2+MGb02jvJy6ADeAa4m4XHGRv9+pedSPMq27kGU3pS+L13nV/pQCLxdRnWBhP7Ob6
          9xsX04vX65+3lhnsdHE6CvcohZBQAE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgw5rF/4175VmxpVYbh1Qqq1w/Qhc49UBmelVCuOIV4k4AAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAANq2g645tpS5u/U
          anaCJaHQ4S1S9UphiR03krbRmV8J7xCjlVEOhG52mR/M9Dr8EqjIMe/rpCS97AIPHpQG7
          Hxq56G9lkSGqpnkh/YEKl0hxd5Ud4f6r82Dk00NXjiA2WL9rQN9CefvBIl+YT2rgQn5x7
          ZNWbSAcdbGQJHTSN8Fr
        '';
        restic-repository = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAADJWDY/bjKSn3Ukq2UAAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgqKdBHSqJbcFeXSGK/mlrKBEvBTRM7daniUXdFpjVFn
          QAEM20DQPLWtvxVrx4D6J6oMJ2qSNV7wfpKCkzktfqkstrjEfA/PQ+HbveIo1Ed87k3f6
          6SN81g+WIkAgfAN6cNZPGts0jTlD4eeA5PLttP3duFaNmzqTF/ahfT0FQsREIrgBjF03E
          XauDZI+ndHrN+xxolQ/QFYHt0bYqAE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgUbrBsQ5Fh5SKwCqNgxAKOOfnFWSATxyX+gezvo7unioAAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAAPVn9BmsriNQL6l
          9z/QvT6RUl7toskLJppy/36o48zBPkN31X76GUpV6yMYmZpjkoZd5DbAGd/AHfdHe34mF
          cQk83Saj39+7f1TwsZdDRdVStvxxnW1oWQqpduZV8uGEJmTORYA+Iw4cxbOSNOIkUEIKR
          ijKqSFpWc6f5my3BJtAfk6bGMRG2r0LwauGvYc=
        '';
        restic-password = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAABRyGUXwi/olafejNkAAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgJRzpFycUNLrwTtaJA0e455EQB6v16Zk/v1rUt7t+eZ
          4AEF6RPWt9Xr9ig/B56w4lN2roro2ShIdhq4qMex1/hJaWx6cBTR8GRiabPJK/Yukgf5w
          wRnztOST9aDxihvuUZoJKnmXt4PtvW04ilPCeAfpsYP6FIN6t1C90TJdn5zZ3TY1HuzCj
          9s1y2+Gm5x0sMMOQtJnUNETM86D3AE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgVk5DopFSqTBqIrSSJS8bPRMWyaW38ZWLh3guwC0XoAcAAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAAJo91D3Uq37JfJW
          9/boNwFaMAsbSvyp7i1J4G8FE5ejdQGfmRFnt9pqXf4nZaqbYshzAlmsu9nGfEHdlxclD
          UNNvnKdL6DQDmlw0eFjWURnLNBcCbKm3o/o=
        '';
      };
    };
    ${config.custom.services.backup.periodic.library.serviceUnitName} = {
      Service.SetCredentialEncrypted = mkSetCredentialEncrypted {
        aws-access-key-id = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAACmap7ZDj/Wq9ODV/4AAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgwdSwJKiLxENutxoQXWlcgDS9X1bTBpafpy1Qc5o7Zs
          MAEEYX+AUyNqf55lvQ9M4p8JQKUjo34zSjF8SybCS16eGbKelNEAYtaV/38NVhbMffGlZ
          oIsUv6FyJewlnmmUkRKgPb20igqdHO+DHVUKP1qaJac/HfIDFT09tmqdgKPpOZBnOHmFn
          lLmp2YmLuupT4KZKvEOEW8MlHc7IAE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgfHhjpiSazcmYSQ5TzhlsQZ713Kti4yj0nTOF04qG37oAAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAABc4Nd9YWlUEMs5
          hSTDh4SsvU6EhyotSIY3NRYZ9YABfrkOVvUaZlW7L9WRRQaolu2mgGnDXmDMT5uZ8tOye
          h7G0q/BZuXpjWBi6yzijHipb1jQkK9ig7s8=
        '';
        aws-secret-access-key = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAAAUugJvJqsyAR5IEWcAAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgg3clteq9o9OnsyQIZvxcmpIgJrENetd7BPZupDr1Bb
          sAEC5TQONBbcX4mjXRicXfwmDQaDhSKhcSgyWNGf+Vbj/LPzdJtjvgLKDdeGzGRzEo4q0
          Qry1Ew+tMqbL2idNEANR+fWwPZQ64qBMvdoSzvGv3LerDm1G+h+l2L22uxaZ370IvYint
          zKPHiOKn6CxfRYQRwg67FBThWLtyAE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgEqTM2BQIkbpRt9IQz5Oxry8yHMMm3hSetu2tHgjJyMAAAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAANNp87npJjrgxyh
          9nPvKyF3mw2TgG1+rXWPpqZYKBehU7elf5QuN1asD2lBmUSUIXnHywAQvb9nRyIEry2dZ
          /Db4uK8HIYt2CpXjHmAUbQzQyHdkQuJJjgNu1L1Sv++6C29rVK4sD3ZGii/j/ey0jyswI
          sJpN+Uo23zTJt08kSSZ
        '';
        restic-repository = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAADL8/j55LxfbigXfKgAAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgDRUHZ/YhuozcM6Hw08sHNzckfe+1FRcKvjARlWovK4
          0AEH49jEq8FFvharGH2gCLQQovSoQXcckNzc4QmIX0IEVUmkzrcpsThSMHtFndbv16ZQL
          vbMjKevz2Ygum1ja+z6o4JWAET4+ES8nLOYzRT+TJHHXJU+UrTkRMloupMc5f7/rB9MXF
          uc2cNZTi2b+0XiKnKB7Q5Q8p6msKAE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgOqq/463NUZq7rqIg1Bf0fBcX2Xzh2/vehUMXbFzJiuoAAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAAKeusO1conEtw+j
          YaZnWeAdzTm3+7uvyaL22GIrCPlDuxO6Pj/05dCXjqni7yAhPbDmkvu1HK9aqTYxIq6CC
          mMDEdPV3MqiATetzFbYF90bz4bxzc/gYrlY423ELpkTi72pE2TvlaiW+HjF0YcDUi9R9L
          s+NIVQwWhDGYp3g1ZWp1WI7zghPx7mwIMoeruVWoa4=
        '';
        restic-password = ''
          70rBNnmpSA6n22iJf58WXSAAAAABAAAADAAAABAAAACWMnkyReSfCRsbIhYAAAAAAAAAA
          AAAAAALACMA8AAAACAAAAAAngAgQWktzT0TZ/jGHF12HcbixaZX/STiLqzWM+sPcZQog7
          YAEF5k3klF39OD7kH4K11l8vpu9NUswKc/dS2P37Q/vz6zG/jhZrSOZO3R6+Ci9VpzbvX
          bNszkd/F9DbN2r2a5eOLFrFtYHShOZ5yOEwNq0COl6A9lqMoUMY3Iwz4Baapg7+PBYg9X
          WzObyOe2rBvvM/6PlSxvLcLQe+GxAE4ACAALAAAEEgAgAAAAAAAAAAAAAAAAAAAAAAAAA
          AAAAAAAAAAAAAAAAAAAEAAgCGx8wGrGJnnIS8M0lhWOJ9KXT/bCkaauh/tbB/i02VQAAA
          AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHAAAAAAAAALbzPrYVqfYhA6c
          uJIZfPXU10p5EAzNg2abI1hv89/MDejmB/hVIMhxbcb1YRw62kZ2GIvHKQeK4cmvs3Kvs
          axiXod72W6YXOvElbj6x5j56Dih0W0Guzs0=
        '';
      };
    };
  };
}
