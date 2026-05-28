# screen-locker - screen locking helper.

# Usage:
#   screen-locker   # lock screen

# Collect logs
exec >>"${XDG_RUNTIME_DIR:-/tmp}/screen-locker.log" 2>&1

waylock -init-color 0x000000 -input-color 0xAAAAAA -fail-color 0xA00000
