# Deployment

## Before Deploying

Verify changes made to system services:

```bash
nixos-rebuild dry-activate --flake .#albedo --sudo --ask-sudo-password --refresh --show-trace 2>&1 | tee trace.log
```

```bash
nixos-rebuild dry-activate --flake .#aether --build-host root@aether.hosts.net.internal --target-host root@aether.hosts.net.internal --refresh --show-trace 2>&1 | tee trace.log
```

```bash
nixos-rebuild dry-activate --flake .#lumine --build-host root@lumine.hosts.net.internal --target-host root@lumine.hosts.net.internal --refresh --show-trace 2>&1 | tee trace.log
```
