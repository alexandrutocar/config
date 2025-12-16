set -e

ipv4_regex="[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"

# ────────────────────────────────────────────────────────────────────────
# TODO: Replace with a stricter IPv6 Regex.
# ────────────────────────────────────────────────────────────────────────
ipv6_regex="[0-9a-fA-F]*:[0-9a-fA-F:]\+"

# shellcheck disable=SC2153
root_domain="$ROOT_DOMAIN"
# shellcheck disable=SC2153
glue_prefix="$GLUE_PREFIX"

api_domain_ipv6="https://api.porkbun.com"
api_domain_ipv4="https://api-ipv4.porkbun.com"

apikey="$PORKBUN_API_TOKEN"
secretapikey="$PORKBUN_API_SECRET"

DO_NOT_LOG=("$apikey" "$secretapikey")

oink() {
	local base path data result status http body message

	base="api/json/v3"
	path="${3:-$api_domain_ipv6}/$base/$1"
    data=$(
		jq --null-input \
			--arg auth '{"secretapikey":"'"$secretapikey"'","apikey":"'"$apikey"'"}' \
			--arg data "${2:-{\}}" \
			'($auth | fromjson) + ($data | fromjson)' 2>/dev/null
	)

	log7 "making a 'POST' request to '$path' with '$data'."

	result=$(
		curl --silent --request POST "$path" \
        	--header "Content-Type: application/json" \
        	--data "$data" \
			--write-out '\n%{http_code}'
	)
	status=$?

	if [ "$status" -ne 0 ]; then
        log3 "curl failed with exit status $status calling '$path'."
        return 1
    fi

	http=$(echo -e "$result" | tail -n 1)
	body=$(echo -e "$result" | sed '$d')

	if ! [[ "$http" -eq 200  || "$http" -eq 202 ]]; then
        log3 "calling '$path' failed with status $http."
        return 1
    fi

    if echo "$body" | jq -e '.status == "SUCCESS"'; then
        log7 "calling '$path' got $body."
        echo "$body"
        return 0
    else
        message=$(echo "$body" | jq -r '.message')
        log3 "calling '$path' failed with status $http and a message '$message'"
        return 1
    fi
}

ping() {
	local domain result status ip

	if [ "$1" -eq 6 ]; then
        domain="$api_domain_ipv6"
    elif [ "$1" -eq 4 ]; then
        domain="$api_domain_ipv4"
    else
		log3 "provided invalid ip version to ping."
		exit 1
	fi

	result=$(oink "ping" "{}" "$domain")
	status=$?

	if [ "$status" -eq 0 ]; then
	    ip=$(echo "$result" | jq -r '.yourIp?')

		if echo "$ip" | grep -q "^$ipv4_regex$"; then
			if [[ "$1" -ne 4 ]]; then
    	    	log6 "address '$ip' mismatch, expected an ipv6 address."
			else
			    log7 "ping $1 returned $ip"
				echo "$ip"
			fi
    	elif echo "$ip" | grep -q "^$ipv6_regex$"; then
			if [[ "$1" -ne 6 ]]; then
    	    	log6 "address '$ip' mismatch, expected an ipv4 address."
			else
				log7 "ping $1 returned $ip"
				echo "$ip"
			fi
    	else
    	    log3 "address '$ip' returned by ping $1 is neither a valid ipv4 nor ipv6 address."
    	fi
	else
	    # Error was already logged.
		exit 1
	fi
}

ipv4=$(ping 4);
ipv6=$(ping 6);

if [[ -z "$ipv4" && -z "$ipv6" ]]; then
    log3 "neither ipv4 nor ipv6 address has been provided."
    exit 1
fi

log6 "checking for existing glue records"

result=$(oink "domain/getGlue/$root_domain")
status=$?

if [ "$status" -eq 0 ]; then
    hosts=$(echo "$result" | jq -r '.hosts?')
	count=$(echo "$hosts" | jq '. | length')

	log6 "got $count records total."

	if [ "$count" -eq 0 ]; then
		if [[ -n "$ipv6" ]]; then
            records='["'"$ipv4"'","'"$ipv6"'"]'
            log7 "creating ipv4 and ipv6 glue records."
        else
            records='["'"$ipv4"'"]'
            log7 "creating ipv4 only glue records."
        fi
		result=$(oink "domain/createGlue/$root_domain/$glue_prefix" '{"ips": '"$records"'}')
		status=$?

		if [ "$status" -eq 0 ]; then
			log6 "recorded '$records' for '$glue_prefix.$root_domain'."
		else
    		# Error was already logged by oink.
			exit 1
		fi
	else
		log7 "current record for $glue_prefix.$root_domain: $hosts"

		# shellcheck disable=SC2016
		if [[ -n "$ipv4" && -n "$ipv6" ]]; then
            # shellcheck disable=SC2016
            filter='(.[] | select(.[0] == "'"$glue_prefix.$root_domain"'")) | .[1] as $record | (($record.v6 | type) == "array" and ($record.v6 | length) == 1 and $record.v6[0] == "'"$ipv6"'") and (($record.v4 | type) == "array" and ($record.v4 | length) == 1 and $record.v4[0] == "'"$ipv4"'")'
		elif [[ -n "$ipv4" ]]; then
            # shellcheck disable=SC2016
			filter='(.[] | select(.[0] == "'"$glue_prefix.$root_domain"'")) | .[1] as $record | (($record.v4 | type) == "array" and ($record.v4 | length) == 1 and $record.v4[0] == "'"$ipv4"'") and (($record.v6? | length) == 0)'
		elif [[ -n "$ipv6" ]]; then
            # shellcheck disable=SC2016
			filter='(.[] | select(.[0] == "'"$glue_prefix.$root_domain"'")) | .[1] as $record | (($record.v6 | type) == "array" and ($record.v6 | length) == 1 and $record.v6[0] == "'"$ipv6"'") and (($record.v4? | length) == 0)'
		else
			log3 "neither ipv4 nor ipv6 address has been provided."
			exit 1
		fi

		log7 "applying '$filter'."

		set +e
		result=$(echo "$hosts" | jq --exit-status --raw-output "$filter" || true)
		set -e

		log7 "recency check for domain=$glue_prefix.$root_domain, ipv4=$ipv4, ipv6=$ipv6 returned '$result'."

		if $result; then
		    log6 "records in '$glue_prefix.$root_domain' match current ip addresses."
			# ────────────────────────────────────────────────────────────────────────
			# TODO: Also check if local zone file matches the ip addresses.
			# ────────────────────────────────────────────────────────────────────────
			exit 0
		fi
	fi
else
    # Error was already logged by oink.
	exit 1
fi

# ...
if [[ -n "$ipv6" ]]; then
    record='["'"$ipv4"'","'"$ipv6"'"]'
    log6 "updating glue record with ipv4 and ipv6 addresses."
else
    record='["'"$ipv4"'"]'
    log6 "updating glue record with ipv4 address only."
fi

result=$(oink "domain/updateGlue/$root_domain/$glue_prefix" '{"ips": '"$record"'}')
status=$?

if [ "$status" -eq 0 ]; then
	log6 "successfully updated glue record for $glue_prefix.$root_domain: $record"
else
	# Error was already logged by oink.
	exit 1
fi
