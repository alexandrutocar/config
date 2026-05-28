# camera-privacy - camera toggle helper.

# Usage:
#   camera-privacy   # toggle camera

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/camera-privacy.log" 2>&1

# ────────────────────────────────────────────────────────────────────────
# TODO: Implement toggling (wpctl) and indicator (brightnessctl).
# ────────────────────────────────────────────────────────────────────────

notify-send \
  --urgency "critical" \
  --expire-time 3000 \
  --app-name "" \
  --category "not-implemented" \
  "the script for toggling cam (on/off) has not been implemented yet"
