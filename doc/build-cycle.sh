#!/usr/bin/env bash
# build-cycle.sh — your personal Hydra replacement

SYSTEM_ATTR="nixosConfigurations.albedo.config.system.build.toplevel"

# 1. Evaluate — catch eval errors before building
nix eval "#${SYSTEM_ATTR}" 2>&1 | tee eval.log
if [ $? -ne 0 ]; then
  echo "EVAL FAILED — staying on current generation"
  exit 1
fi

# 2. Dry-run to see what would be built
nix build "$.#{SYSTEM_ATTR}" --dry-run 2>&1 | tee dry.log

# 3. Actually build, pushing to local cache
nix build ".#${SYSTEM_ATTR}" \
  --out-link /var/lib/builds/latest \
  --post-build-hook /etc/nix/push-to-cache.sh

# 4. Gate: only advance if build succeeded
if [ $? -eq 0 ]; then
  echo "BUILD OK — ready to switch"
  # Optionally auto-switch, or leave for manual intervention
  # nixos-rebuild switch --flake ...
fi