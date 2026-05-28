# tcam.bash - camera toggle helper.

# Usage:
#   tcamp.bash   # toggle camera

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/microphone-privacy.log" 2>&1

# ────────────────────────────────────────────────────────────────────────
# TODO: Implement toggling (wpctl) and indicator (brightnessctl).
# ────────────────────────────────────────────────────────────────────────

notify-send \
  --urgency "critical" \
  --app-name "" \
  --expire-time 3000 \
  --category "not-implemented" \
  "the script for toggling mic (on/off) has not been implemented yet"
