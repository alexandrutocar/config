#!/usr/bin/env bash

# MIT License
#
# Copyright (c) 2020 Jason Koh
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

auth_token="${AUTH_TOKEN}"						# Your API Token or Global API Key
zone_identifier="${ZONE_IDENTIFIER}"			# Can be found in the "Overview" tab of your domain
record_name="${RECORD_NAME}"					# Which record you want to be synced
ttl=3600                             			# Set the DNS TTL (seconds)
proxy="false"                        			# Set the proxy to true or false

###########################################
## Check if we have a public IP
###########################################
REGEX_IPV4="^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))$"
IP_SERVICES=(
	"https://api.ipify.org"
	"https://ipv4.icanhazip.com"
	"https://ipinfo.io/ip"
)

# Try all the ip services for a valid IPv4 address
for service in "${IP_SERVICES[@]}"; do
	RAW_IP=$(curl -s "$service")
	if [[ $RAW_IP =~ $REGEX_IPV4 ]]; then
		CURRENT_IP="${BASH_REMATCH[0]}"
		logger -s "DDNS: Fetched IP $CURRENT_IP"
		break
	else
		logger -s "DDNS: IP service $service failed."
	fi
done

# Exit if IP fetching failed
if [[ -z $CURRENT_IP ]]; then
	logger -s "DDNS: Failed to find a valid IP."
	exit 2
fi

###########################################
## Seek for the A record
###########################################

logger "DDNS: Check Initiated"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
	-H "Authorization: Bearer $auth_token" \
	-H "Content-Type: application/json")

###########################################
## Check if the domain has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
	logger -s "DDNS: Record does not exist, perhaps create one first? (${CURRENT_IP} for ${record_name})"
	exit 1
fi

###########################################
## Get existing IP
###########################################
old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
# Compare if they're the same
if [[ $CURRENT_IP == "$old_ip" ]]; then
	logger "DDNS: IP ($CURRENT_IP) for ${record_name} has not changed."
	exit 0
fi

###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | sed -E 's/.*"id":"([A-Za-z0-9_]+)".*/\1/')

###########################################
## Change the IP@Cloudflare using the API
###########################################
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
	-H "Authorization: Bearer $auth_token" \
	-H "Content-Type: application/json" \
	--data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$CURRENT_IP\",\"ttl\":$ttl,\"proxied\":${proxy}}"
