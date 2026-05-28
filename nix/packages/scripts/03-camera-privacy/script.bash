# tcam.bash - camera toggle helper.

# Usage:
#   tcamp.bash   # toggle camera

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/camera-privacy.log" 2>&1

# ────────────────────────────────────────────────────────────────────────
# TODO: Implement toggling (wpctl) and indicator (brightnessctl).
# ────────────────────────────────────────────────────────────────────────

notify-send \
  --urgency "critical" \
  --expire-time 3000 \
  --category "not-implemented" \
  "the script for toggling cam (on/off) has not been implemented yet"
