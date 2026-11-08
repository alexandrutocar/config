#!/usr/bin/env bash
#
# Sync preview branch: brings ci/<ID> up to date with the repository's
# default branch and leaves the checkout at the result, the base commit of
# this run:
#   - preview branch missing, or already merged into the default branch:
#     starts anew from the default branch
#   - preview branch already contains the default branch: its tip
#   - otherwise: the default branch merged into the preview branch's tip.
#     A conflict in flake.lock alone is resolved with the default branch's
#     version, since the update regenerates it anyway; any other conflict
#     needs a manual merge.
#
# The base commit is pushed to ci/<ID>, never forced (commits pushed by hand
# are kept; a push that isn't a fast-forward fails instead), and checked
# out, so later steps of the job can use HEAD.
#
# Needs the full history (actions/checkout with fetch-depth: 0).
#
# Environment: ID, the workflow's id (preview branch: ci/<ID>).
# Output: base-commit.

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

default_branch() {
	local output label ref

	output="$(git ls-remote --symref origin HEAD)" ||
		die "cannot reach the remote origin"
	# First line: "ref: refs/heads/<branch>\tHEAD".
	read -r label ref _ <<<"${output}"
	[[ ${label} == "ref:" && ${ref} == refs/heads/* ]] ||
		die "cannot read the default branch of origin"
	printf '%s' "${ref#refs/heads/}"
}

# Fetches a remote branch and prints its commit, nothing when it doesn't
# exist.
fetch_branch() {
	local branch="$1"

	git ls-remote --exit-code --heads origin "${branch}" >/dev/null || return 0
	git fetch --quiet origin "refs/heads/${branch}" || die "cannot fetch ${branch}"
	git rev-parse FETCH_HEAD
}

# Merges a commit into another and prints the merge commit. A conflict in
# flake.lock alone is resolved with the merged commit's version.
merge() {
	local into="$1" commit="$2" message="$3" conflicts

	git checkout --quiet --detach "${into}"
	if ! git merge --quiet --no-edit -m "${message}" "${commit}" >&2; then
		conflicts="$(git diff --name-only --diff-filter=U)"
		if [[ ${conflicts} != "flake.lock" ]]; then
			git merge --abort || true
			die "${message,} failed, merge it by hand:" \
				"conflicts in ${conflicts//$'\n'/, }"
		fi
		git checkout --quiet --theirs flake.lock
		git add flake.lock
		git commit --quiet --no-edit >&2
		log "Resolved the flake.lock conflict with $(short "${commit}")'s version"
	fi
	git rev-parse HEAD
}

main() {
	local preview default default_commit tip base

	preview="$(preview_branch)"
	go_to_root
	[[ "$(git rev-parse --is-shallow-repository)" == false ]] ||
		die "the full history is needed (actions/checkout with fetch-depth: 0)"
	set_git_identity

	default="$(default_branch)"
	default_commit="$(fetch_branch "${default}")"
	[[ -n ${default_commit} ]] || die "remote branch ${default} not found"
	tip="$(fetch_branch "${preview}")"

	if [[ -z ${tip} ]] || git merge-base --is-ancestor "${tip}" "${default_commit}"; then
		base="${default_commit}"
		log "Base: ${default} @ $(short "${base}") (starting anew)"
	elif git merge-base --is-ancestor "${default_commit}" "${tip}"; then
		base="${tip}"
		log "Base: ${preview} @ $(short "${base}")"
	else
		base="$(merge "${tip}" "${default_commit}" "Merge ${default} into ${preview}")"
		log "Base: ${default} merged into ${preview} @ $(short "${base}")"
	fi

	git checkout --quiet --detach "${base}"
	if [[ ${base} != "${tip}" ]]; then
		push_preview "${base}"
	fi
	output base-commit "${base}"
}

main "$@"
