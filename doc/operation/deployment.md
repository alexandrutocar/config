# Deployment

## Before Deploying

Verify changes made to system services:

```bash
nixos-rebuild dry-activate --flake .#albedo --sudo --ask-sudo-password --refresh --show-trace 2>&1 | tee trace.log
```

```bash
nixos-rebuild dry-activate --flake .#beidou --build-host root@beidou.hosts.net.internal --target-host root@beidou.hosts.net.internal --refresh --show-trace 2>&1 | tee trace.log
```

```bash
nixos-rebuild dry-activate --flake .#collei --build-host root@collei.hosts.net.internal --target-host root@collei.hosts.net.internal --refresh --show-trace 2>&1 | tee trace.log
```
