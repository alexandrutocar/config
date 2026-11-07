#!/usr/bin/env bash
#
# Collect Nix systems: lists the flake's nixosConfigurations at the
# checked-out commit, for the job matrix. Run after sync-preview-branch.sh,
# which leaves the checkout at the base commit.
#
# Output: nix-systems, a JSON list of names.

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

main() {
	local commit systems

	go_to_root
	commit="$(git rev-parse HEAD)"
	systems="$(nix eval --json \
		--expr "builtins.attrNames $(flake_expr "${commit}").nixosConfigurations" </dev/null)" ||
		die "cannot list the nixosConfigurations at $(short "${commit}")"

	log "Nix systems at $(short "${commit}"): ${systems}"
	output nix-systems "${systems}"
}

main "$@"
