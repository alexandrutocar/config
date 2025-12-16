# volume.bash — volume control helper.

# Usage:
#   volume.bash +   # increase volume by 5%
#   volume.bash -   # decrease volume by 5%
#   volume.bash /   # toggle mute

# Where to store the last notification ID
nid_file="${XDG_RUNTIME_DIR:-/tmp}/volume.nid"

# Ensure the file exists
touch "$nid_file"

# Read previous notification ID (if any)
if [ -s "$nid_file" ]; then
    replace_flag="--replace-id=$(cat "$nid_file")"
else
    replace_flag=""
fi

if [ "$1" = "+" ] || [ "$1" = "-" ]; then
    wpctl set-volume @DEFAULT_SINK@ "5%$1" --limit 1.0
elif [ "$1" = "/" ]; then
    wpctl set-mute @DEFAULT_SINK@ toggle
else
    log3 "Expected '+' (increase), '-' (decrease) or '/' (mute)."
    exit 1
fi

# Get updated volume % and status (if it is 'muted' or 'unmuted')
read -r level state <<< "$(wpctl get-volume @DEFAULT_SINK@ | awk '{printf "%d %s\n", $2*100, ($3=="[MUTED]"?"muted":"unmuted")}')"

# Send notification and save the returned ID
nid=$(
    notify-send \
        --urgency=critical \
        --expire-time=1500 \
        --category=volume \
        --hint string:synchronous:volume \
        --hint "int:value:$level" \
        --print-id \
        "$replace_flag" \
        "Lautstärke $([ "$state" == "muted" ] && echo "[\]")"
)

echo "$nid" > "$nid_file"
