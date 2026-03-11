#!/usr/bin/env bash
# build-cycle.sh — your personal Hydra replacement

NIXPKGS_PIN="github:nixos/nixpkgs/9dcb002ca1690658be4a04645215baea8b95f31d"
SYSTEM_ATTR="nixosConfigurations.aether.config.system.build.toplevel"

# 1. Evaluate — catch eval errors before building
nix eval "${NIXPKGS_PIN}#${SYSTEM_ATTR}" --no-build 2>&1 | tee eval.log
if [ $? -ne 0 ]; then
  echo "EVAL FAILED — staying on current generation"
  exit 1
fi

# 2. Dry-run to see what would be built
nix build "${NIXPKGS_PIN}#${SYSTEM_ATTR}" --dry-run 2>&1 | tee drybuild.log

# 3. Actually build, pushing to local cache
nix build "${NIXPKGS_PIN}#${SYSTEM_ATTR}" \
  --out-link /var/lib/builds/latest \
  --post-build-hook /etc/nix/push-to-cache.sh

# 4. Gate: only advance if build succeeded
if [ $? -eq 0 ]; then
  echo "BUILD OK — ready to switch"
  # Optionally auto-switch, or leave for manual intervention
  # nixos-rebuild switch --flake ...
fi