# brightness.bash - brightness control helper.

# Usage:
#   brightness.bash +   # increase brightness by 5%
#   brightness.bash -   # decrease brightness by 5%

# Where to store the last notification ID
nid_file="${XDG_RUNTIME_DIR:-/tmp}/brightness.nid"

# Ensure the file exists
touch "$nid_file"

# Read previous notification ID (if any)
if [[ -s "$nid_file" ]] && [[ "$(cat "$nid_file")" =~ ^[0-9]+$ ]]; then
    replace_flag=("--replace-id=$(cat "$nid_file")")
else
    replace_flag=()
fi

if [ "$1" = "+" ]; then
    info=$(brightnessctl --class backlight --device "*" --machine-readable set +5%)
elif [ "$1" = "-" ]; then
    info=$(brightnessctl --class backlight --device "*" --machine-readable set 5%-)
else
    echo "error: expected '+' (increase) or '-' (decrease)" >&2
    exit 1
fi

# Extract updated brightness % from -readable output
level=$(awk -F',' '{gsub("%","",$4); print $4}' <<<"$info") # echo "$info" | cut -d',' -f4 | tr -d '%'


# Send notification and save the returned ID
nid=$(
    notify-send \
        --urgency=critical \
        --expire-time=1500 \
        --category=brightness \
        --hint string:synchronous:brightness \
        --hint "int:value:$level" \
        --print-id \
        "${replace_flag[@]}" \
        "Helligkeit"
)

if [[ "$nid" =~ ^[0-9]+$ ]]; then
    echo "$nid" > "$nid_file"
fi