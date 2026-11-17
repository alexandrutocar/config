# shellcheck disable=SC2148
#
# RADII ENDPOINT WATCHDOG
# -----------------------
# Runs on a timer, with the configuration file radii generates as its only
# argument:
#
#   - For every tunnel to a hub that has had no handshake for `stale`
#     seconds, it moves the tunnel to the hub's next endpoint. DNS names are
#     resolved again each time, within the address families this host can
#     use. After a move it waits `settle` seconds before the next one.
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

# TUNNELS TO HUBS
# ---------------
for entry in "${hubs[@]}"; do
	read -r interface key candidates <<<"$entry"
	up "$interface" || continue

	silent=$(age "$interface" "$key")
	((silent >= stale)) || continue

	switched=$(cat "$state/$interface.switched" 2>/dev/null || echo 0)
	((now - switched >= settle)) || continue

	read -r -a list <<<"$candidates"
	mapfile -t endpoints < <(for candidate in "${list[@]}"; do resolve "$candidate"; done | awk '!seen[$0]++')
	if ((${#endpoints[@]} == 0)); then
		echo "$interface: no endpoint resolves" >&2
		continue
	fi

	# The tunnel starts on the first endpoint; move on from the current one.
	index=$(cat "$state/$interface.index" 2>/dev/null || echo 0)
	index=$(((index + 1) % ${#endpoints[@]}))

	wg set "$interface" peer "$key" endpoint "${endpoints[index]}"
	echo "$index" >"$state/$interface.index"
	echo "$now" >"$state/$interface.switched"
	if ((silent >= now)); then since="no handshake yet"; else since="no handshake for ${silent}s"; fi
	echo "$interface: $since, trying ${endpoints[index]}"
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
