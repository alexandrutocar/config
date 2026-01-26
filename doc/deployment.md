# Deployment

## Before Deploying

Verify changes made to system services:

```bash
nixos-rebuild dry-activate --flake .#albedo --sudo --ask-sudo-password
```

```bash
nixos-rebuild dry-activate --flake .#aether --build-host root@aether.ip --target-host root@aether.ip
```

---

Verify changes made to package set:

```bash
nix run nixpkgs#nvd diff /run/current-system $(nix build .#nixosConfigurations.albedo.config.system.build.toplevel --no-link --print-out-paths)
```

```bash
nix run nixpkgs#nvd diff $(ssh root@aether.ip readlink -f /run/current-system) $(nix build .#nixosConfigurations.aether.config.system.build.toplevel --no-link --print-out-paths)
```
