# shellcheck disable=SC2148
#
# RADII ENDPOINT WATCHDOG
# -----------------------
# Runs on a timer, and on spokes also whenever a link becomes routable, with
# the configuration file radii generates as its only argument:
#
#   - For every tunnel to a hub whose endpoint this host has no route to
#     (e.g. IPv6 on an IPv4-only network), it moves the tunnel at once to
#     the hub's most preferred endpoint that has one.
#   - For every tunnel to a hub that has had no handshake for `stale`
#     seconds, it moves the tunnel to the hub's next endpoint with a route,
#     `settle` seconds after its last move at the earliest.
#   - DNS names are resolved again each time, within the address families
#     this host can use.
#   - On hubs, it keeps a route to each device's host address only while the
#     device's tunnel has a recent handshake. The route carries protocol
#     `proto`, which babeld announces, so the site reaches the device through
#     the hub it uses.
#
# Configuration lines:
#   stale <seconds> | settle <seconds> | proto <number> | ipv4 <0|1> | ipv6 <0|1>
#   hub <interface> <public key> <candidate>…
#       candidate: a,<endpoint> (address and port, as WireGuard writes it)
#                  n,<DNS name>,<port>
#   device <interface> <public key> <host address/128>

config=$1
state=${RUNTIME_DIRECTORY:-/run/radii-watchdog}
now=$(date +%s)

stale=180
settle=60
proto=200
ipv4=1
ipv6=1
hubs=()
devices=()

while read -r kind rest; do
	case $kind in
	stale) stale=$rest ;;
	settle) settle=$rest ;;
	proto) proto=$rest ;;
	ipv4) ipv4=$rest ;;
	ipv6) ipv6=$rest ;;
	hub) hubs+=("$rest") ;;
	device) devices+=("$rest") ;;
	"" | "#"*) ;;
	*) echo "radii-watchdog: unknown line: $kind" >&2 ;;
	esac
done <"$config"

# Whether the interface exists and is up: a tunnel a spoke brings up by hand
# is left alone while it is down.
up() {
	[ -n "$(ip -o link show dev "$1" up 2>/dev/null)" ]
}

# Seconds since the tunnel's last handshake with its peer; large if never.
age() {
	local last
	last=$(wg show "$1" latest-handshakes | awk -v key="$2" '$1 == key { print $2 }')
	echo $((now - ${last:-0}))
}

# The endpoints of one candidate: an address as it is, a DNS name resolved
# within this host's address families (without IPv4-mapped answers).
resolve() {
	local kind host port
	IFS=, read -r kind host port <<<"$1"
	case $kind in
	a) echo "$host" ;;
	n)
		if [ "$ipv6" = 1 ]; then
			{ getent ahostsv6 "$host" || true; } | awk -v port="$port" '$1 !~ /^::ffff:/ { print "[" $1 "]:" port }'
		fi
		if [ "$ipv4" = 1 ]; then
			{ getent ahostsv4 "$host" || true; } | awk -v port="$port" '{ print $1 ":" port }'
		fi
		;;
	esac
}

# Whether this host can send to an endpoint (as WireGuard writes it) now: it
# has a route to the endpoint's address, and an address to send from that is
# not link-local. Without one the endpoint cannot work, e.g. an IPv6 endpoint
# on an IPv4-only network.
routable() {
	local host=${1%:*} source
	host=${host#[}
	host=${host%]}
	source=$(ip route get "$host" 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }') || true
	[[ -n $source && $source != fe80:* && $source != 169.254.* ]]
}

# TUNNELS TO HUBS
# ---------------
for entry in "${hubs[@]}"; do
	read -r interface key candidates <<<"$entry"
	up "$interface" || continue

	current=$(wg show "$interface" endpoints | awk -v key="$key" '$1 == key { print $2 }')
	silent=$(age "$interface" "$key")

	# A tunnel leaves an endpoint without a route at once. On one with a
	# route, it waits until it is stale, and until `settle` has passed since
	# its last move.
	if [[ -n $current && $current != "(none)" ]] && routable "$current"; then
		dead=0
		((silent >= stale)) || continue
		switched=$(cat "$state/$interface.switched" 2>/dev/null || echo 0)
		((now - switched >= settle)) || continue
	else
		dead=1
	fi

	read -r -a list <<<"$candidates"
	mapfile -t endpoints < <(for candidate in "${list[@]}"; do resolve "$candidate"; done | awk '!seen[$0]++')
	if ((${#endpoints[@]} == 0)); then
		echo "$interface: no endpoint resolves" >&2
		continue
	fi

	usable=()
	for endpoint in "${endpoints[@]}"; do
		if routable "$endpoint"; then usable+=("$endpoint"); fi
	done
	if ((${#usable[@]} == 0)); then
		# Said once, not on every run while the host is offline.
		if [ ! -e "$state/$interface.unroutable" ]; then
			echo "$interface: no endpoint has a route" >&2
			touch "$state/$interface.unroutable"
		fi
		continue
	fi
	rm -f "$state/$interface.unroutable"

	# The usable endpoint after the current one. The most preferred one when
	# the current one has no route, or is not among them (WireGuard followed
	# the hub elsewhere, or a name now resolves differently).
	next=${usable[0]}
	if ((! dead)); then
		for i in "${!usable[@]}"; do
			if [[ ${usable[i]} == "$current" ]]; then
				next=${usable[(i + 1) % ${#usable[@]}]}
				break
			fi
		done
	fi
	if [[ $next == "$current" ]]; then continue; fi

	wg set "$interface" peer "$key" endpoint "$next"
	echo "$now" >"$state/$interface.switched"
	if ((dead)); then
		since="no route to ${current:-its endpoint}"
	elif ((silent >= now)); then
		since="no handshake yet"
	else
		since="no handshake for ${silent}s"
	fi
	echo "$interface: $since, trying $next"
done

# DEVICES (HUBS ONLY)
# -------------------
for entry in "${devices[@]}"; do
	read -r interface key address <<<"$entry"
	up "$interface" || continue

	if (($(age "$interface" "$key") < stale)); then
		ip -6 route replace "$address" dev "$interface" proto "$proto"
	else
		ip -6 route del "$address" dev "$interface" proto "$proto" 2>/dev/null || true
	fi
done
