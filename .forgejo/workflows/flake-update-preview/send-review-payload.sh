#!/usr/bin/env bash
#
# Send review payload: posts .<ID>/payload.json (build-review-payload.sh)
# to the review webhook. The URL and header go to curl through its config
# on STDIN, so they don't show up in the process list.
#
# Environment:
#   ID, the workflow's id.
#   WEBHOOK_URL, the webhook's URL.
#   WEBHOOK_HEADER, its auth header, "Name: value".

set -euo pipefail

# shellcheck source=.helpers/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/.helpers/common.sh"

# Quotes a value for a curl config file.
curl_quote() {
	local value="${1//\\/\\\\}"

	printf '"%s"' "${value//\"/\\\"}"
}

main() {
	local payload

	[[ -n ${WEBHOOK_URL:-} ]] || die "WEBHOOK_URL is not set"
	[[ -n ${WEBHOOK_HEADER:-} ]] || die "WEBHOOK_HEADER is not set"
	go_to_root
	payload="$(payload_file)"
	[[ -f ${payload} ]] || die "missing ${payload}, run build-review-payload.sh first"

	# The webhook's reply, then a newline, goes to the log.
	curl --config - --fail-with-body --silent --show-error --write-out '\n' \
		--header 'Content-Type: application/json' \
		--data-binary "@${payload}" >&2 <<EOF || die "sending the payload failed"
url = $(curl_quote "${WEBHOOK_URL}")
header = $(curl_quote "${WEBHOOK_HEADER}")
EOF
	log "Sent $(wc -c <"${payload}") bytes"
}

main "$@"
