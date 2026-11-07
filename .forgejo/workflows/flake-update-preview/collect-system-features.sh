#!/usr/bin/env bash
#
# Collect system features: what a Nix system and its nested evaluations
# (containers) use at the checked-out commit: packages, enabled modules
# and options set by this repository, each mapped to the flake input and
# file that provides it (collect-system-features.expr.nix). Writes
# .<ID>/records/stats-<phase>-<system>.json.
#
# The core part (packages, modules) runs once and lists the targets; the
# options part runs once per target, each in its own nix process, so an
# error Nix can't catch only loses that target's options. When the core
# part fails, the record lists no targets, and evaluate-system-closure.sh
# evaluates the system itself.
#
# Usage: collect-system-features.sh <base|next> <system>
# Environment: ID, the workflow's id.

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

FEATURES_NIX="$(dirname "${BASH_SOURCE[0]}")/collect-system-features.expr.nix"
readonly FEATURES_NIX

# Runs one part of the features expression, for the whole system or for one
# of its targets. Writes the targets to <out>.json, null when the part
# fails, and Nix's messages to <out>.err.
collect() {
	local part="$1" out="$2" target="${3:-}"
	local -a args=(
		"flake = $(flake_expr "${COMMIT}")"
		"host = $(nix_str "${SYSTEM}")"
		"part = $(nix_str "${part}")"
	)
	if [[ -n ${target} ]]; then
		args+=("target = $(nix_str "${target}")")
	fi

	if nix_call "${FEATURES_NIX}" "${args[@]}" >"${out}.json" 2>"${out}.err"; then
		log "  ${target:-${SYSTEM}}: ${part} features collected"
	else
		log "  ${target:-${SYSTEM}}: ${part} features failed," \
			"last lines of ${out}.err:"
		tail -n 15 "${out}.err" | sed 's/^/    /' >&2
		echo null >"${out}.json"
	fi
}

# Prints the stats record: the targets of the core part, each with the items
# of its options part added (a failed part adds none); no targets when the
# core part failed.
stats_record_json() {
	local core="$1"
	shift

	jq -n --arg phase "${PHASE}" --arg host "${SYSTEM}" \
		--slurpfile core "${core}" '
      [inputs | arrays | .[]] as $options
      | {
          kind: "stats", phase: $phase, host: $host,
          targets: ($core[0] | if . == null then null else map(
            .id as $id
            | .items += [$options[] | select(.id == $id) | .items[]]
          ) end)
        }' \
		"$@" </dev/null
}

main() {
	require_phase_and_system "$@"
	readonly PHASE="$1" SYSTEM="$2"
	[[ -f ${FEATURES_NIX} ]] || die "missing ${FEATURES_NIX}"
	go_to_root
	COMMIT="$(git rev-parse HEAD)"
	readonly COMMIT

	local out record id options
	local -a options_files=()
	out="$(artifacts_dir "${PHASE}")/features-${SYSTEM}"
	record="$(stats_record "${PHASE}" "${SYSTEM}")"
	log "Features of ${SYSTEM} (${PHASE}, $(short "${COMMIT}"))"

	collect core "${out}-core"
	if [[ $(<"${out}-core.json") == null ]]; then
		log "  ${SYSTEM}: options skipped, core failed"
	else
		while read -r id; do
			options="${out}-options-$(file_name "${id}")"
			collect options "${options}" "${id}"
			options_files+=("${options}.json")
		done < <(jq -r '.[].id' "${out}-core.json")
	fi

	stats_record_json "${out}-core.json" "${options_files[@]}" >"${record}"
	log "  ${SYSTEM}: done in ${SECONDS}s"
}

main "$@"
