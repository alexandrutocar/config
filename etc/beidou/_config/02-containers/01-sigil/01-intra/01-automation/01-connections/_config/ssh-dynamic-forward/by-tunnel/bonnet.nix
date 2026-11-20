{
  config,
  lib,
  ...
}: let
  inherit (lib.extra.cs.systemd) credentialsDirectory mkSetCredentialEncrypted;
  inherit (lib.strings) removeSuffix;
in let
  sshDynamicForwardSystemdService = removeSuffix ".service" config.services.ssh-dynamic-forward.tunnels.bonnet.serviceName;
in {
  systemd = {
    services = {
      ${sshDynamicForwardSystemdService} = {
        serviceConfig = {
          SetCredentialEncrypted = mkSetCredentialEncrypted {
            # (umask 077; dir=$(mktemp -d -p "${XDG_RUNTIME_DIR:-/dev/shm}"); trap 'rm -rf "$dir"' EXIT; ssh-keygen -q -t ed25519 -N '' -C 'alex@beidou' -f "$dir/key" && systemd-creds encrypt --with-key=host --name=id_ed25519 "$dir/key" - && cat "$dir/key.pub" >&2)
            id_ed25519 = ''
              Whxqht+dQJax1aZeCGLxmiAAAAABAAAADAAAABAAAAAsfhvQILUr1yfrqB4AAAAAZolLsPmB8kwjVjs
              0CiM4u/vJSJehlP90jOmT2CQq+h7UQ5by9XCj6UCH/3hIyZRhQuvWlTHzgciJTjfUSCJEKztmIwR8V/
              kwbivAPlCPdmGEThxyA+b++MBYtFKMaLJXOqEuVqQxTTex3QU3W2B+0qd20v4+tManzBchk5PEaE2wF
              +Ik2LvjZkGh3/jL8P3rJyjYFXemYY5SLlT5bpUn7pEat5NO9qnlExjijcFzK8OsHLslx5gKCbPE79I1
              JwuwJzeA8j74ZO/ryOwKuaFyxjKJLfgAL5mCc3sZcQ8A3VesBtZViExcHzvj9DZHFxTrb/pTdqwsG4+
              v1RID/JJyVriHYTeC7I6PE6znSYHZntCkgsuhsV3pI98oCO8Qnv4V8xcp2jh73PvpJnMsRSAfJKEduC
              UZWIrz+0QgClufulGgH5soyCv20uRu57HWAnTuarVqji61TsYrIHsyUcQtHBF0X9E0dGjpKtKTkHZPa
              RH2gmut7sOqfl7KMvYBrM1PB5Y7TqxDRfwAnL2+FP8w2lie+lKpAqrPNpHiO0Zi+bGi4E7aUdwire4n
              nry1jhFKbs61AC2xA4229PmKEBQL
            '';
          };
        };
      };
    };
  };

  services = {
    ssh-dynamic-forward = {
      tunnels = {
        bonnet = {
          knownHosts = "login-stud.informatik.uni-bonn.de ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBpukn0zkZZ8Gw3fFIT/Gjh04B1B4/TbkVRUVWsvWp7j";
          hostName = "login-stud.informatik.uni-bonn.de";

          user = "tocara1";
          listen = {
            address = "localhost";
            port = 1080;
          };
          settings = {
            IdentityFile = "${credentialsDirectory sshDynamicForwardSystemdService}/id_ed25519";
          };
        };
      };
    };
  };
}
