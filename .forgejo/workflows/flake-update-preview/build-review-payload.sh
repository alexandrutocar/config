#!/usr/bin/env bash
#
# Build review payload: combines the records of both phases in
# .<ID>/records/ (merged from the jobs' artifacts) and the flake metadata of
# both commits into .<ID>/payload.json (build-review-payload.expr.nix), then
# replaces the store paths of each changed used file with a unified diff.
#
# The checkout is the update commit; its parent is the base commit (needs
# actions/checkout with fetch-depth: 2).
#
# Environment: ID, the workflow's id (preview branch: ci/<ID>).

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

PAYLOAD_NIX="$(dirname "${BASH_SOURCE[0]}")/build-review-payload.expr.nix"
readonly PAYLOAD_NIX

# Lines kept per diff of a changed used file.
readonly DIFF_LINES=300

# Writes the flake metadata (inputs and their locks) at a commit to
# .<ID>/<phase>/metadata.json, where build-review-payload.expr.nix reads it.
write_metadata() {
	local phase="$1" commit="$2" dir

	dir="$(artifacts_dir "${phase}")"
	nix flake metadata --json "$(flake_url "${commit}")" \
		>"${dir}/metadata.json" </dev/null ||
		die "cannot read the flake metadata at $(short "${commit}")"
}

# Prints the unified diff of two versions of a file (/dev/null for a missing
# one), cut after DIFF_LINES lines.
diff_of() {
	local file="$1" before="$2" after="$3"

	{ diff -u --label "a/${file}" --label "b/${file}" "${before}" "${after}" || true; } |
		awk -v max="${DIFF_LINES}" '
        NR <= max
        END { if (NR > max) printf "… %d more lines\n", NR - max }'
}

# Prints {path, diff} for every changed file in the payload: its path in the
# payload and the diff of its two versions.
changed_file_diffs() {
	local payload="$1" path file before after

	while IFS=$'\t' read -r path file before after; do
		jq -nc --argjson path "${path}" \
			--rawfile diff <(diff_of "${file}" "${before}" "${after}") \
			'{$path, $diff}'
	done < <(jq -r '
      path(.inputs[].changed[]) as $path | getpath($path)
      | [($path | tojson), .file, .prev // "/dev/null", .next // "/dev/null"]
      | @tsv' \
		"${payload}")
}

# Replaces the store paths (prev, next) of every changed file in the payload
# with the diff of the two.
add_diffs() {
	local payload="$1"

	jq --slurpfile diffs <(changed_file_diffs "${payload}") '
      reduce $diffs[] as $d (.;
        setpath($d.path; getpath($d.path) | del(.prev, .next) + {diff: $d.diff}))' \
		"${payload}" >"${payload}.tmp"
	mv "${payload}.tmp" "${payload}"
}

main() {
	local branch artifacts records payload commit base
	local -a record_files

	branch="$(preview_branch)"
	[[ -f ${PAYLOAD_NIX} ]] || die "missing ${PAYLOAD_NIX}"
	go_to_root
	artifacts="$(artifacts_dir)"
	records="$(artifacts_dir records)"
	payload="$(payload_file)"
	commit="$(git rev-parse HEAD)"
	base="$(git rev-parse --verify --quiet 'HEAD^')" ||
		die "the base commit is missing (actions/checkout with fetch-depth: 2)"

	mapfile -t record_files < <(find "${records}" -name '*.json')
	((${#record_files[@]} > 0)) || die "no records in ${records}"
	log "Payload of $(short "${base}")..$(short "${commit}")" \
		"from ${#record_files[@]} records"

	write_metadata base "${base}"
	write_metadata next "${commit}"
	nix_call "${PAYLOAD_NIX}" \
		"artifacts = $(nix_str "${artifacts}")" \
		"branch = $(nix_str "${branch}")" \
		"base = $(nix_str "${base}")" \
		"commit = $(nix_str "${commit}")" \
		>"${payload}" || die "cannot build the payload"
	add_diffs "${payload}"

	log "Payload: ${payload} ($(wc -c <"${payload}") bytes," \
		"$(jq -r '"\(.inputs | length) inputs, \(.targets | length) targets"' \
			"${payload}"))"
}

main "$@"
