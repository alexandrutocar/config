# Networking

Everything lives under a single global 40-bit ULA prefix: `fda0:9527:68ee::/48`

```sh
printf 'fd%s:%s:%s::/48\n' $(openssl rand -hex 1) $(openssl rand -hex 2) $(openssl rand -hex 2)
```

Then each net lives in its own subnet:

- `hosts` -> `4f8a` 
  - `aether` -> `fda0:9527:68ee:4f8a:f7f3:176c:41e0:4098/128`
  - `albedo` -> `fda0:9527:68ee:4f8a:ad9c:4066:9123:5d9a/128`
  - `keqing` -> `fda0:9527:68ee:4f8a:afbf:7002:aa5f:a363/128`
  - `lumine` -> `fda0:9527:68ee:4f8a:46a1:b595:357f:c251/128`
- `intra` -> `f1b6`
- `inter` -> `c84c`
...

fda0:9527:68ee:b800:1

# Credentials

This is intermediary trust anchor between host (hypervisor) and
the nspawn container. It is used to encrypt credentials consumed
by services running on the container.
To generate the credential use:

```sh
{ xxd -r -p <<< "$(systemd-id128 show "cd4e799127fc425b9f9ca0b3ec1b4f1a" --app-specific=d3acecba-0dad-4cdf-b8c9-381528936c58 --value)"; head -c 4096 /dev/urandom; } | systemd-creds encrypt --name=credential.secret --with-key=host+tpm2 - -
```

