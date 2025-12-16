# launcher.bash - application launcher helper.

# Usage:
#   launcher.bash   # launch overlay

read -r -a APPLICATION <<< "$(tofi-drun)"

if [ "${#APPLICATION[@]}" -gt 0  ]; then
    uwsm-app -- "${APPLICATION[@]}"
fi
