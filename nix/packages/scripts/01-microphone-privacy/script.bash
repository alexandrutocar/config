# microphone-privacy - microphone mute toggle helper.

# Usage:
#   microphone-privacy   # toggle microphone mute

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/microphone-privacy.log" 2>&1

# Where to store the last notification ID
nid_file="${XDG_RUNTIME_DIR:-/tmp}/microphone-privacy.nid"

# Ensure the file exists
touch "$nid_file"

# Read previous notification ID (if any)
if [[ -s "$nid_file" ]] && [[ "$(cat "$nid_file")" =~ ^[0-9]+$ ]]; then
  replace_flag=("--replace-id=$(cat "$nid_file")")
else
  replace_flag=()
fi

if wpctl get-volume @DEFAULT_SOURCE@ | grep -q '\[MUTED\]'; then
  wpctl set-mute @DEFAULT_SOURCE@ 0
  muted="0"
else
  wpctl status \
    | awk '
            /^Audio/              { in_audio=1 }
            /^Video/              { in_audio=0 }
            in_audio && /Sources/ { in_sources=1; next }
            in_audio && /Sinks/   { in_sources=0 }
            in_audio && /Filters/ { in_sources=0 }
            in_sources && match($0, /[0-9]+\./) {
              print substr($0, RSTART, RLENGTH-1)
            }
          ' \
    | xargs -I{} wpctl set-mute {} 1
  muted="1"
fi

# Send notification and save the returned ID
nid=$(
  notify-send \
    --urgency=critical \
    --expire-time=1500 \
    --category=privacy \
    --app-name "" \
    --hint string:synchronous:mic \
    --print-id \
    "${replace_flag[@]}" \
    "Mikrofon $(if [[ "$muted" == "1" ]]; then echo "[stumm]"; else echo "[aktiv]"; fi)"
)

if [[ "$nid" =~ ^[0-9]+$ ]]; then
  echo "$nid" >"$nid_file"
fi
