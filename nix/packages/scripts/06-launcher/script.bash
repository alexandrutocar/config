# launcher - application launcher helper.

# Usage:
#   launcher   # launch overlay

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/launcher.log" 2>&1

read -r -a APPLICATION <<<"$(tofi-drun)"

if [ "${#APPLICATION[@]}" -gt 0 ]; then
  uwsm-app -- "${APPLICATION[@]}"
fi
