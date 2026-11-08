#!/usr/bin/env bash
#
# Update flake inputs: updates flake.lock at the checked-out commit (the base
# commit of this run), commits it on top with Nix's summary of the updated
# inputs as message body, and pushes the commit to ci/<ID>. Never forced: a
# push that isn't a fast-forward (commits pushed by hand meanwhile) fails.
#
# Environment: ID, the workflow's id (preview branch: ci/<ID>).
# Output: next-commit, the update commit; empty when flake.lock is already
# up to date.

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

main() {
	local base console next

	require_id
	go_to_root
	set_git_identity
	base="$(git rev-parse HEAD)"
	log "Updating the flake inputs at $(short "${base}")"

	# Nix reports the updated inputs on STDERR: shown, and kept for the
	# commit message.
	console="$(nix flake update --flake "$(flake_url)" 2>&1 >/dev/null </dev/null |
		tee /dev/stderr)" || die "nix flake update failed"

	git add flake.lock
	if git diff --cached --quiet; then
		log "Nothing to update: flake.lock at $(short "${base}") is up to date"
		output next-commit ""
		return 0
	fi

	# Nix's summary starts at the first "• Updated input" line.
	git commit --quiet --file - <<EOF
chore(flake): update inputs

$(sed -n '/^•/,$p' <<<"${console}")
EOF
	next="$(git rev-parse HEAD)"
	push_preview "${next}"
	output next-commit "${next}"
}

main "$@"
