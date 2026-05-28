# Set up ControlMasters
SSH_CONTROL_DIR="$HOME/.ssh/control.d"
mkdir -p "$SSH_CONTROL_DIR"

# Check if it's before 8 AM or after 8 PM
if [ "$(date +%H)" -lt 8 ] || [ "$(date +%H)" -ge 20 ]; then
  notify-send --expire-time=5000 "Die Rechner stehen von 20:00 bis 08:00 Uhr nicht zur Verfügung."
  exit
fi

# Fetch the computer rooms
ROOMS=$(
  curl -s "https://gsg.informatik.uni-bonn.de/doku.php" \
    | grep -o "U1.[0-9]\{3\}" \
    | cut -d'.' -f2 \
    | sort \
    | uniq
)

# Select the room
ROOM=$(
  printf '%s\n' "$ROOMS" \
    | tofi --prompt-text "Raum:"
)
[ -z "$ROOM" ] && exit

# Check if the room is available
DATETIME=$(date "+%Y-%m-%d %H:00:00 %z %Z")
RESERVED=$(
  curl -s "https://gsg.informatik.uni-bonn.de/doku.php?id=rooms:U1.$ROOM" \
    | pup "div.hour time[datetime=\"$DATETIME\"] + div.events div text{}"
)

# ────────────────────────────────────────────────────────────────────────
# TODO: Bestimme ob ich in dem Raum bin anhand der aktuellen
#       Router-Verbindung. Die Routern im Computer-Pool haben
#       jeweils eine einzigartige MAC-Addresse.
# ────────────────────────────────────────────────────────────────────────
if [ -n "$RESERVED" ]; then
  notify-send --expire-time=5000 "Raum $ROOM ist durch $RESERVED belegt."
  notify-send --expire-time=10000 "Verbinde sich nur mit dem PC wenn du gerade im Raum bist."
fi

# Fetch the computers in the computer room
COMPUTERS=$(
  curl -s "https://gsg.informatik.uni-bonn.de/doku.php?id=en:pool:U1.$ROOM" \
    | grep -o 'pool-u-[0-9]\{3\}-[0-9]\{2\}' \
    | cut -d'-' -f4 \
    | sort \
    | uniq
)
if [ -z "$COMPUTERS" ]; then
  notify-send --expire-time=5000 "Kein Rechner ist verfügbar im Raum $ROOM."
  exit
fi

# Select the computer
COMPUTER=$(
  printf '%s\n' "$COMPUTERS" \
    | tofi --prompt-text "Rechner:"
)
[ -z "$COMPUTER" ] && exit

# Connect to the computer
DOMAIN="pool-u-$ROOM-$COMPUTER.informatik.uni-bonn.de"
SOCKET="$SSH_CONTROL_DIR/$DOMAIN"

# Check for any active connections
ACTIVE_CONNECTION=$(find "$SSH_CONTROL_DIR" -maxdepth 1 -type s -name "pool-u-*.informatik.uni-bonn.de" -print -quit 2>/dev/null)

if [[ -n $ACTIVE_CONNECTION ]]; then
  ACTIVE_DOMAIN=$(basename "$ACTIVE_CONNECTION")

  if [[ $ACTIVE_DOMAIN == "$DOMAIN" ]]; then
    notify-send --expire-time=5000 "Verwende bestehende Verbindung zu $DOMAIN."

    # Reuse the existing connection
    foot -e zsh -c "ssh -o ControlPath=$ACTIVE_CONNECTION $ACTIVE_DOMAIN"
    exit
  else
    NOTIFICATION=$(notify-send --print-id "Bereits mit $ACTIVE_DOMAIN verbunden. Verbindung wiederverwenden oder eine neue Verbindung zu $DOMAIN aufbauen?")
    REUSE_OPTION=("$ACTIVE_DOMAIN" "$DOMAIN")
    REUSE_DOMAIN=$(
      printf '%s\n' "${REUSE_OPTION[@]}" \
        | tofi --prompt-text "Benutze:"
    )

    # Delete the notification
    if [ -n "$NOTIFICATION" ]; then
      notify-send --replace-id="$NOTIFICATION" --expire-time=1 "" # effectively removes it
    fi

    # Conditional branch
    case "$REUSE_DOMAIN" in
      "$ACTIVE_DOMAIN")
        foot -e zsh -c "ssh -o ControlPath=$ACTIVE_CONNECTION $ACTIVE_DOMAIN"
        exit
        ;;
      "$DOMAIN")
        foot -e zsh -c "ssh -o ControlMaster=auto -o ControlPath=$SOCKET -o ControlPersist=30s $DOMAIN"
        ;;
      *)
        exit
        ;;
    esac
  fi

fi

notify-send --expire-time=5000 "Verbinde mit $DOMAIN."

foot -e zsh -c "ssh -o ControlMaster=auto -o ControlPath=$SOCKET -o ControlPersist=30s $DOMAIN"
