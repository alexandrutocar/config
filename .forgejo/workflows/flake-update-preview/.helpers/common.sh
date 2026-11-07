# shellcheck shell=bash
#
# Helpers shared by the workflow's scripts, which source this file as
# .helpers/common.sh from their own directory. Not executed on its own.
#
# Messages go to STDERR: STDOUT is reserved for job outputs and for values
# the functions print.

# A failure inside $(…) stops the script too, not just the substitution.
shopt -s inherit_errexit

# ── Messages ─────────────────────────────────────────────────────────────

log() {
	printf '%s\n' "$*" >&2
}

die() {
	printf '[%s]: error: %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
	exit 1
}

# ── Arguments ────────────────────────────────────────────────────────────

require_id() {
	[[ -n ${ID:-} ]] || die "ID is not set (see env in the workflow file)"
}

# Checks the arguments of a per-system script: <base|next> <system>. Phase
# base is the commit before the update, next the update commit.
require_phase_and_system() {
	(($# == 2)) || die "usage: $(basename "$0") <base|next> <system>"
	[[ $1 == base || $1 == next ]] || die "phase must be base or next, not '$1'"
}

# ── Repository ───────────────────────────────────────────────────────────

# Changes to the root of the repository these scripts live in.
go_to_root() {
	local here root

	here="$(dirname "${BASH_SOURCE[0]}")"
	root="$(git -C "${here}" rev-parse --show-toplevel)" ||
		die "${here} is not inside a git repository"
	cd "${root}" || die "cannot change to ${root}"
}

# Author and committer of the commits the workflow makes (merges of the
# default branch, flake.lock updates).
set_git_identity() {
	git config user.name "pierro"
	git config user.email "pierro@noreply.intra.net.internal"
}

preview_branch() {
	require_id
	printf 'ci/%s' "${ID}"
}

# Pushes a commit to the preview branch. Never forced: a push that isn't a
# fast-forward (commits pushed by hand meanwhile) fails.
push_preview() {
	local commit="$1" branch

	branch="$(preview_branch)"
	git push --quiet origin "${commit}:refs/heads/${branch}" ||
		die "cannot push $(short "${commit}") to ${branch}"
	log "Pushed $(short "${commit}") to ${branch}"
}

short() {
	printf '%s' "${1:0:7}"
}

# ── Artifacts ────────────────────────────────────────────────────────────
#
# The workflow's files live in .<ID>/ below the repository root (call these
# after go_to_root):
#
#   records/stats-<phase>-<system>.json  collect-system-features.sh
#   records/eval-<phase>-<target>.json   evaluate-system-closure.sh
#   <phase>/                             logs and intermediate files
#   payload.json                         build-review-payload.sh
#
# The jobs' records/ are merged into one before build-review-payload.sh.

# Prints the artifacts directory, or a subdirectory of it, creating it.
artifacts_dir() {
	local dir

	require_id
	dir="${PWD}/.${ID}${1:+/$1}"
	mkdir -p "${dir}" || die "cannot create ${dir}"
	printf '%s' "${dir}"
}

stats_record() {
	local phase="$1" system="$2" records

	records="$(artifacts_dir records)"
	printf '%s/stats-%s-%s.json' "${records}" "${phase}" "${system}"
}

payload_file() {
	local dir

	dir="$(artifacts_dir)"
	printf '%s/payload.json' "${dir}"
}

# Turns a target id (e.g. albedo/sigil/web/1234) into a file name.
file_name() {
	printf '%s' "${1//\//__}"
}

# Publishes a job output: key=value on STDOUT, and in GITHUB_OUTPUT when set.
output() {
	printf '%s=%s\n' "$1" "$2" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
}

# ── Nix ──────────────────────────────────────────────────────────────────

# The flake URL of this checkout, at a commit when one is given.
# shallow=1: CI checkouts are usually shallow (Nix would count the history
# otherwise).
flake_url() {
	if [[ -n ${1:-} ]]; then
		printf 'git+file://%s?rev=%s&shallow=1' "${PWD}" "$1"
	else
		printf 'git+file://%s?shallow=1' "${PWD}"
	fi
}

# A Nix expression for the flake at a commit of this checkout.
flake_expr() {
	printf '(builtins.getFlake "%s")' "$(flake_url "$1")"
}

# A Nix string literal holding a value.
nix_str() {
	local value="${1//\\/\\\\}"

	value="${value//\"/\\\"}"
	printf '"%s"' "${value//\$/\\\$}"
}

# Calls the function in a .nix file with named arguments, each given as
# "name = <Nix expression>", and prints the result as JSON.
#
# --impure: the expressions read files outside the store (the records).
nix_call() {
	local file="$1"
	shift

	nix eval --impure --json --file "${file}" \
		--apply "f: f { $(printf '%s; ' "$@")}" </dev/null
}
