# sshot.bash - screenshot helper.

# Usage:
#   sshot.bash   # make screenshot

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/screen.log" 2>&1

# Try to take a screenshot of the selected area and copy to clipboard
if ! grim -g "$(slurp)" - | wl-copy; then
  notify-send \
    --urgency=critical \
    --expire-time=3000 \
    --category=screenshot \
    "Fehler beim Erstellen des Screenshots."
  exit 1
fi

# Success notification
notify-send \
  --urgency=normal \
  --expire-time=1500 \
  --category=screenshot \
  "Kopiert in die Zwischenablage."
