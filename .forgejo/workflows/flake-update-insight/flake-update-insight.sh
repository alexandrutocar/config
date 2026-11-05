#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# Flake Update Insight
#
# Keeps INSIGHT_BRANCH as a running flake update on top of MAIN_BRANCH: each
# run merges MAIN_BRANCH in, updates flake.lock in a new commit on top, and
# reports what that update changes for every host to a webhook, which
# writes the review checklist of the INSIGHT_BRANCH -> MAIN_BRANCH PR.
# Commits made on INSIGHT_BRANCH by hand are kept: it's never force-pushed.
#
# Meant for CI: each stage runs in its own job, in a throwaway checkout
# (see flake-update-insight.yml). Locally, run the workflow with act or
# `forgejo-runner exec` and INSIGHT_BRANCH pointing at a test branch.
#
# - prepare		base commit: INSIGHT_BRANCH with MAIN_BRANCH merged in, or
#				MAIN_BRANCH when the branch is gone or merged. Pushes it.
# - collect		stats and probes of one commit for some or all hosts.
# - update		flake.lock update on the base, committed and pushed.
# - report		combines the collected records into the webhook payload.
#
# ────────────────────────────────────────────────────────────────────────
# Usage
# ────────────────────────────────────────────────────────────────────────
#
# flake-update-insight.sh prepare
# flake-update-insight.sh collect <prev|next> <commit> [host...]
# flake-update-insight.sh update <base>
# flake-update-insight.sh report <base> <next> [fresh]
#
# prepare and update print key=value results (base, fresh, hosts; next)
# and append them to $GITHUB_OUTPUT when set.
#
# ────────────────────────────────────────────────────────────────────────
# Environment
# ────────────────────────────────────────────────────────────────────────
#
# WORK_DIR		directory shared by the stages (default: .insight)
# PROBE_LIMIT   	bytes of console output kept per probe, cut at a line
#				boundary (default: 200000)
# DIFF_LINES		lines kept per diff of a changed used file (default: 300)
# MAIN_BRANCH		branch the insight branch is based on (default: main)
# INSIGHT_BRANCH	branch the updates are pushed to
#				(default: ci/flake-update-insight)
# WEBHOOK_URL		webhook url (required if DO_NOT_SEND=0)
# DO_NOT_SEND		1 to print instead of sending (default: 0)
#
# Commits use git's identity variables (GIT_AUTHOR_NAME, ...), set by the
# workflow.
#
# ────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly STATS_EXPR="${SCRIPT_DIR}/stats.nix"
readonly FINAL_EXPR="${SCRIPT_DIR}/final.nix"
readonly HOST_PROBE='["config","system","build","toplevel"]'

readonly PROBE_LIMIT="${PROBE_LIMIT:-200000}"
readonly DIFF_LINES="${DIFF_LINES:-300}"
readonly MAIN_BRANCH="${MAIN_BRANCH:-main}"
readonly INSIGHT_BRANCH="${INSIGHT_BRANCH:-ci/flake-update-insight}"
readonly DO_NOT_SEND="${DO_NOT_SEND:-0}"

# Set in main.
work_dir=""

# ────────────────────────────────────────────────────────────────────────
# Prints a message to stderr. Stdout is reserved for results.
# Arguments:
#   Message.
# ────────────────────────────────────────────────────────────────────────
log() {
	printf '%s\n' "$*" >&2
}

# ────────────────────────────────────────────────────────────────────────
# Prints an error and exits.
# Arguments:
#   Message.
# ────────────────────────────────────────────────────────────────────────
die() {
	log "error: $*"
	exit 1
}

# ────────────────────────────────────────────────────────────────────────
# Prints a result as key=value and appends it to $GITHUB_OUTPUT when set.
# Arguments:
#   Key, value.
# ────────────────────────────────────────────────────────────────────────
emit() {
	printf '%s=%s\n' "$1" "$2" | tee -a "${GITHUB_OUTPUT:-/dev/null}"
}

# ────────────────────────────────────────────────────────────────────────
# Prints a locked flake reference for a commit of this checkout. shallow=1
# because CI checkouts are shallow (Nix would count the history otherwise).
# Arguments:
#   Commit hash.
# ────────────────────────────────────────────────────────────────────────
flake_ref() {
	printf 'git+file://%s?rev=%s&shallow=1' "${PWD}" "$1"
}

# ────────────────────────────────────────────────────────────────────────
# Prints a Nix expression that evaluates to the flake at a reference.
# Arguments:
#   Flake reference.
# ────────────────────────────────────────────────────────────────────────
flake_expr() {
	printf '(builtins.getFlake "%s")' "$1"
}

# ────────────────────────────────────────────────────────────────────────
# Turns a target id into a file name.
# Arguments:
#   Target id, e.g. albedo/sigil/web/1234.
# ────────────────────────────────────────────────────────────────────────
file_name() {
	printf '%s' "${1//\//__}"
}

# ────────────────────────────────────────────────────────────────────────
# Prints the last PROBE_LIMIT bytes of a log, starting at a full line.
# Arguments:
#   Log file.
# ────────────────────────────────────────────────────────────────────────
trim_log() {
	if (($(wc -c <"$1") > PROBE_LIMIT)); then
		tail -c "${PROBE_LIMIT}" "$1" | tail -n +2
	else
		cat "$1"
	fi
}

# ────────────────────────────────────────────────────────────────────────
# Fails early when a companion file or a required command is missing.
# Arguments:
#   Command (prepare, collect, update, report).
# ────────────────────────────────────────────────────────────────────────
check_requirements() {
	local file cmd
	local -a cmds=(git nix jq)

	for file in "${STATS_EXPR}" "${FINAL_EXPR}"; do
		[[ -f ${file} ]] || die "missing ${file}: stats.nix and final.nix must be next to this script"
	done

	if [[ $1 == report ]]; then
		cmds+=(diff)
		if [[ ${DO_NOT_SEND} != 1 ]]; then
			: "${WEBHOOK_URL:?WEBHOOK_URL is not set}"
			cmds+=(curl)
		fi
	fi
	for cmd in "${cmds[@]}"; do
		command -v "${cmd}" >/dev/null || die "missing command: ${cmd}"
	done
}

# ── Git ─────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────
# Fetches a remote branch and prints its commit, or nothing when the
# branch doesn't exist.
# Arguments:
#   Branch.
# ────────────────────────────────────────────────────────────────────────
fetch_branch() {
	if git ls-remote --exit-code --heads origin "$1" >/dev/null; then
		git fetch --quiet origin "refs/heads/$1"
		git rev-parse FETCH_HEAD
	fi
}

# ────────────────────────────────────────────────────────────────────────
# Checks out the insight branch and merges MAIN_BRANCH into it. A conflict
# in flake.lock alone is resolved with MAIN_BRANCH's version, since the
# update regenerates the lock anyway; any other conflict needs a manual
# merge.
# Arguments:
#   Insight branch commit, main branch commit.
# ────────────────────────────────────────────────────────────────────────
merge_main() {
	local conflicts

	git checkout --quiet --detach "$1"
	if git merge --quiet --no-edit -m "Merge ${MAIN_BRANCH} into ${INSIGHT_BRANCH}" "$2" >&2; then
		return
	fi

	conflicts="$(git diff --name-only --diff-filter=U)"
	if [[ ${conflicts} != flake.lock ]]; then
		git merge --abort
		die "merging ${MAIN_BRANCH} into ${INSIGHT_BRANCH} conflicts in: ${conflicts//$'\n'/, }; merge it by hand"
	fi
	git checkout --quiet --theirs flake.lock
	git add flake.lock
	git commit --quiet --no-edit >&2
	log "Resolved flake.lock conflict with ${MAIN_BRANCH}'s version"
}

# ────────────────────────────────────────────────────────────────────────
# Pushes a commit to INSIGHT_BRANCH, never forced: it must fast-forward, so
# commits pushed by hand meanwhile are never lost (the push fails instead).
# Arguments:
#   Commit hash.
# ────────────────────────────────────────────────────────────────────────
push_insight() {
	git push --quiet origin "$1:refs/heads/${INSIGHT_BRANCH}"
	log "Pushed ${1:0:7} to ${INSIGHT_BRANCH}"
}

# ── Collection ──────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────
# Prints the names of all nixosConfigurations as a JSON list.
# Arguments:
#   Flake reference.
# ────────────────────────────────────────────────────────────────────────
list_hosts() {
	nix eval --json --expr "builtins.attrNames $(flake_expr "$1").nixosConfigurations" </dev/null
}

# ────────────────────────────────────────────────────────────────────────
# Runs one part of stats.nix and writes its targets to <out>.json, or null
# when it fails. On failure only the end of the error is shown; the full
# output stays in <out>.err.
# Arguments:
#   Flake reference, host, part (core or options), target id (empty for
#   all targets of the host), output path prefix.
# ────────────────────────────────────────────────────────────────────────
run_stats() {
	local ref="$1" host="$2" part="$3" target="$4" out="$5"
	local expr target_expr=null

	if [[ -n ${target} ]]; then
		target_expr="\"${target}\""
	fi
	expr="($(<"${STATS_EXPR}")) {
		flake = $(flake_expr "${ref}");
		host = \"${host}\";
		part = \"${part}\";
		target = ${target_expr};
	}"

	if nix eval --json --expr "${expr}" >"${out}.json" 2>"${out}.err" </dev/null; then
		log "  ${target:-${host}}: stats (${part}) collected"
	else
		log "  ${target:-${host}}: stats (${part}) failed, last lines of ${out}.err:"
		tail -n 15 "${out}.err" | sed 's/^/    /' >&2
		echo null >"${out}.json"
	fi
}

# ────────────────────────────────────────────────────────────────────────
# Writes the stats record of a host. The core part runs once and lists the
# targets (host and nested evaluations); the options part runs once per
# target in its own process, so an uncatchable error only loses that
# target's options. A failed core part is recorded as null (the host is
# still probed) and skips the options part.
# Arguments:
#   Phase (prev or next), flake reference, host.
# ────────────────────────────────────────────────────────────────────────
collect_stats() {
	local phase="$1" ref="$2" host="$3"
	local out="${work_dir}/${phase}/stats-${host}"
	local record="${work_dir}/records/stats-${phase}-${host}.json"
	local id
	local -a ids options_files=()

	run_stats "${ref}" "${host}" core "" "${out}-core"

	if [[ "$(jq -c . "${out}-core.json")" == null ]]; then
		log "  ${host}: options skipped, core failed"
		jq -n --arg phase "${phase}" --arg host "${host}" \
			'{kind: "stats", phase: $phase, host: $host, targets: null}' >"${record}"
		return
	fi

	mapfile -t ids < <(jq -r '.[].id' "${out}-core.json")
	for id in "${ids[@]}"; do
		run_stats "${ref}" "${host}" options "${id}" "${out}-options-$(file_name "${id}")"
		options_files+=("${out}-options-$(file_name "${id}").json")
	done

	jq -n --arg phase "${phase}" --arg host "${host}" --slurpfile core "${out}-core.json" '
		[inputs | arrays | .[]] as $extra
		| {
			kind: "stats", phase: $phase, host: $host,
			targets: ($core[0] | map(.id as $id | .items += [$extra[] | select(.id == $id) | .items[]]))
		}' \
		"${options_files[@]}" >"${record}"
}

# ────────────────────────────────────────────────────────────────────────
# Prints "<id>\t<attribute path>" for every target of a host that has a
# probe. Falls back to the host's toplevel when the stats failed.
# Arguments:
#   Phase, host.
# ────────────────────────────────────────────────────────────────────────
list_probes() {
	jq -r --arg host "$2" --argjson fallback "${HOST_PROBE}" '
		(.targets // [{id: $host, probe: $fallback}])[]
		| select(.probe != null)
		| [.id, (["nixosConfigurations", $host] + .probe | map(@json) | join("."))]
		| @tsv' \
		"${work_dir}/records/stats-$1-$2.json"
}

# ────────────────────────────────────────────────────────────────────────
# Evaluates the drvPath of a target and writes its eval record.
# Arguments:
#   Phase, flake reference, target id, attribute path below the flake.
# ────────────────────────────────────────────────────────────────────────
probe() {
	local phase="$1" ref="$2" id="$3" attr="$4"
	local out
	local success=true

	out="${work_dir}/${phase}/eval-$(file_name "${id}")"

	if ! nix eval --raw --expr "$(flake_expr "${ref}").${attr}.drvPath" \
		>/dev/null 2>"${out}.log" </dev/null; then
		success=false
	fi
	trim_log "${out}.log" >"${out}.console"

	jq -n --arg phase "${phase}" --arg id "${id}" --argjson success "${success}" \
		--rawfile console "${out}.console" \
		'{kind: "eval", phase: $phase, id: $id, success: $success, console: $console}' \
		>"${work_dir}/records/eval-${phase}-$(file_name "${id}").json"

	log "  ${id}: $([[ ${success} == true ]] && echo evaluates || echo "evaluation FAILED")"
}

# ────────────────────────────────────────────────────────────────────────
# Replaces the store paths of every changed file in the payload with a
# unified diff of at most DIFF_LINES lines.
# Arguments:
#   Payload file.
# ────────────────────────────────────────────────────────────────────────
add_diffs() {
	local payload="$1" node file prev next lines
	local out="${work_dir}/diff" diffs="${work_dir}/diffs.jsonl"

	: >"${diffs}"
	while IFS=$'\t' read -r node file prev next; do
		{ diff -u --label "a/${file}" --label "b/${file}" "${prev}" "${next}" || true; } >"${out}"
		lines="$(wc -l <"${out}")"
		if ((lines > DIFF_LINES)); then
			head -n "${DIFF_LINES}" "${out}" >"${out}.cut"
			printf '… %d more lines\n' "$((lines - DIFF_LINES))" >>"${out}.cut"
			mv "${out}.cut" "${out}"
		fi
		jq -nc --arg node "${node}" --arg file "${file}" --rawfile diff "${out}" \
			'{$node, $file, $diff}' >>"${diffs}"
	done < <(jq -r '
		.inputs[] | .node as $node | .changed[]
		| [$node, .file, .prev // "/dev/null", .next // "/dev/null"] | @tsv' "${payload}")

	jq --slurpfile diffs "${diffs}" '
		.inputs |= map(.node as $node | .changed |= map(
			.file as $file
			| del(.prev, .next)
			+ {diff: ([$diffs[] | select(.node == $node and .file == $file) | .diff][0] // "")}
		))' "${payload}" >"${payload}.tmp"
	mv "${payload}.tmp" "${payload}"
}

# ── Commands ────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────
# Determines the base commit and pushes it to INSIGHT_BRANCH:
#
# - branch missing, or fully contained in MAIN_BRANCH (PR merged):
#   MAIN_BRANCH, a new cycle (fresh=true),
# - MAIN_BRANCH already contained in the branch: the branch tip,
# - otherwise: MAIN_BRANCH merged into the branch tip.
#
# Needs the full history (actions/checkout with fetch-depth: 0).
# Outputs:
#   base, fresh, hosts (JSON list).
# ────────────────────────────────────────────────────────────────────────
cmd_prepare() {
	local main tip base fresh=false

	[[ "$(git rev-parse --is-shallow-repository)" == false ]] ||
		die "prepare needs the full history (actions/checkout with fetch-depth: 0)"

	main="$(fetch_branch "${MAIN_BRANCH}")"
	[[ -n ${main} ]] || die "remote branch ${MAIN_BRANCH} not found"
	tip="$(fetch_branch "${INSIGHT_BRANCH}")"

	if [[ -z ${tip} ]] || git merge-base --is-ancestor "${tip}" "${main}"; then
		base="${main}"
		fresh=true
		log "Base: ${MAIN_BRANCH} @ ${base:0:7} (new cycle)"
	elif git merge-base --is-ancestor "${main}" "${tip}"; then
		base="${tip}"
		log "Base: ${INSIGHT_BRANCH} @ ${base:0:7}"
	else
		merge_main "${tip}" "${main}"
		base="$(git rev-parse HEAD)"
		log "Base: ${MAIN_BRANCH} merged into ${INSIGHT_BRANCH} @ ${base:0:7}"
	fi

	if [[ ${base} != "${tip}" ]]; then
		push_insight "${base}"
	fi

	emit base "${base}"
	emit fresh "${fresh}"
	emit hosts "$(list_hosts "$(flake_ref "${base}")")"
}

# ────────────────────────────────────────────────────────────────────────
# Collects stats and probes of a commit into WORK_DIR.
# Arguments:
#   Phase (prev or next), commit, hosts (default: all).
# ────────────────────────────────────────────────────────────────────────
cmd_collect() {
	(($# >= 2)) || die "usage: collect <prev|next> <commit> [host...]"
	local phase="$1" commit="$2"
	shift 2
	local ref host id attr start
	local -a hosts=("$@")

	ref="$(flake_ref "${commit}")"
	if ((${#hosts[@]} == 0)); then
		mapfile -t hosts < <(list_hosts "${ref}" | jq -r '.[]')
	fi
	mkdir -p "${work_dir}/${phase}" "${work_dir}/records"
	log "Collecting ${phase} (${commit:0:7}): ${hosts[*]}"

	for host in "${hosts[@]}"; do
		start="${SECONDS}"
		collect_stats "${phase}" "${ref}" "${host}"
		while IFS=$'\t' read -r id attr; do
			probe "${phase}" "${ref}" "${id}" "${attr}"
		done < <(list_probes "${phase}" "${host}")
		log "  ${host}: done in $((SECONDS - start))s"
	done
}

# ────────────────────────────────────────────────────────────────────────
# Updates flake.lock on the base, commits it on top with Nix's summary of
# the changed inputs as message body, and pushes it.
# Arguments:
#   Base commit.
# Outputs:
#   next (empty when flake.lock is already up to date).
# ────────────────────────────────────────────────────────────────────────
cmd_update() {
	(($# == 1)) || die "usage: update <base>"
	local next
	local summary="${work_dir}/update.log"

	git checkout --quiet --detach "$1"
	if ! nix flake update --flake "git+file://${PWD}?shallow=1" 2>"${summary}" </dev/null; then
		cat "${summary}" >&2
		die "nix flake update failed"
	fi
	cat "${summary}" >&2
	git add flake.lock

	if git diff --cached --quiet; then
		log "Nothing to update: flake.lock at ${1:0:7} is up to date"
		emit next ""
		return
	fi

	git commit --quiet --file - <<-EOF
		chore(flake): update inputs

		$(sed -n '/^•/,$p' "${summary}")
	EOF
	next="$(git rev-parse HEAD)"
	log "$(git log -1 --format='Committed %h %s')"

	push_insight "${next}"
	emit next "${next}"
}

# ────────────────────────────────────────────────────────────────────────
# Builds the payload from the records in WORK_DIR, adds the diffs of the
# changed used files, and sends it.
# Arguments:
#   Base commit, update commit, fresh (true when the cycle is new).
# ────────────────────────────────────────────────────────────────────────
cmd_report() {
	(($# >= 2)) || die "usage: report <base> <next> [fresh]"
	local base="$1" next="$2" fresh="${3:-false}"
	local payload="${work_dir}/payload.json"

	mkdir -p "${work_dir}/prev" "${work_dir}/next"
	nix flake metadata --json "$(flake_ref "${base}")" >"${work_dir}/prev/metadata.json" </dev/null
	nix flake metadata --json "$(flake_ref "${next}")" >"${work_dir}/next/metadata.json" </dev/null

	jq -n --arg branch "${INSIGHT_BRANCH}" --arg base "${base}" --argjson fresh "${fresh}" \
		'{branch: $branch, base: $base, fresh: $fresh}' >"${work_dir}/run.json"

	nix eval --impure --json --file "${FINAL_EXPR}" \
		--apply "final: final { workDir = \"${work_dir}\"; }" >"${payload}" </dev/null
	add_diffs "${payload}"
	log "Payload: $(wc -c <"${payload}") bytes"

	if [[ ${DO_NOT_SEND} == 1 ]]; then
		jq . "${payload}"
		return
	fi
	curl --fail-with-body --silent --show-error \
		--header 'Content-Type: application/json' \
		--data-binary "@${payload}" "${WEBHOOK_URL}"
	echo
}

# ── Main ────────────────────────────────────────────────────────────────

main() {
	(($# >= 1)) || die "usage: $0 <prepare|collect|update|report> [arguments]"
	local command="$1"

	shift
	check_requirements "${command}"
	cd "$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"

	work_dir="$(realpath -m -- "${WORK_DIR:-.insight}")"
	mkdir -p "${work_dir}"

	case "${command}" in
	prepare) cmd_prepare ;;
	collect) cmd_collect "$@" ;;
	update) cmd_update "$@" ;;
	report) cmd_report "$@" ;;
	*) die "unknown command: ${command} (prepare, collect, update, report)" ;;
	esac
}

main "$@"
