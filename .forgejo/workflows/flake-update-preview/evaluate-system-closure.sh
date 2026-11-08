#!/usr/bin/env bash
#
# Evaluate system closure: evaluates the toplevel derivation (drvPath) of a
# Nix system and of each nested evaluation listed in its features record
# (the system itself without one) at the checked-out commit. Writes success
# and console output (warnings, traces, errors) to
# .<ID>/records/eval-<phase>-<target>.json, and the full console to
# .<ID>/<phase>/eval-<target>.log.
#
# Usage: evaluate-system-closure.sh <base|next> <system>
# Environment: ID, the workflow's id.

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

# Bytes of console output kept per target in its record.
readonly CONSOLE_LIMIT=200000

# Attribute path of a system's toplevel, below nixosConfigurations.<system>.
readonly TOPLEVEL='["config","system","build","toplevel"]'

# Prints the last CONSOLE_LIMIT bytes of a log, starting at a full line.
console_tail() {
	if (($(wc -c <"$1") > CONSOLE_LIMIT)); then
		tail -c "${CONSOLE_LIMIT}" "$1" | tail -n +2
	else
		cat "$1"
	fi
}

# Prints "<id>\t<attribute path below the flake>" for each target with a
# toplevel in the system's features record; for the system itself when the
# record is missing or lists no targets (its core part failed).
list_targets() {
	local record

	record="$(stats_record "${PHASE}" "${SYSTEM}")"
	{ cat "${record}" 2>/dev/null || echo '{}'; } |
		jq -r --arg system "${SYSTEM}" --argjson toplevel "${TOPLEVEL}" '
        (.targets // [{id: $system, probe: $toplevel}])[]
        | select(.probe != null)
        | [.id, (["nixosConfigurations", $system] + .probe
            | map(@json) | join("."))]
        | @tsv'
}

# Evaluates the drvPath of a target and writes its eval record.
evaluate() {
	local id="$1" attr="$2" name logfile records success=true

	name="$(file_name "${id}")"
	logfile="$(artifacts_dir "${PHASE}")/eval-${name}.log"
	records="$(artifacts_dir records)"

	nix eval --raw --expr "$(flake_expr "${COMMIT}").${attr}.drvPath" \
		>/dev/null 2>"${logfile}" </dev/null || success=false

	jq -n --arg phase "${PHASE}" --arg id "${id}" \
		--argjson success "${success}" \
		--rawfile console <(console_tail "${logfile}") \
		'{kind: "eval", phase: $phase, id: $id, success: $success,
      console: $console}' \
		>"${records}/eval-${PHASE}-${name}.json"

	if [[ ${success} == true ]]; then
		log "  ${id}: evaluates"
	else
		log "  ${id}: evaluation FAILED"
	fi
}

main() {
	require_phase_and_system "$@"
	readonly PHASE="$1" SYSTEM="$2"
	go_to_root
	COMMIT="$(git rev-parse HEAD)"
	readonly COMMIT

	local id attr
	log "Closure of ${SYSTEM} (${PHASE}, $(short "${COMMIT}"))"
	while IFS=$'\t' read -r id attr; do
		evaluate "${id}" "${attr}"
	done < <(list_targets)
	log "  ${SYSTEM}: done in ${SECONDS}s"
}

main "$@"
