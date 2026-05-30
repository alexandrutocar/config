declare -A mutes # [node_id]=true|false

# ────────────────────────────────────────────────────────────────────────
# NOTE: Extract numeric IDs of all nodes listed under the Sources section.
# ────────────────────────────────────────────────────────────────────────
extract='
  .[]
  | select(
      (.info.props != null and .info.props."media.class" == "Audio/Source")
      or
      (.info == null)
    )
  | {
      id: .id,
      mute: (
        if .info.params.Props != null
        then .info.params.Props[0].mute
        else null
        end
      ),
      # ────────────────────────────────────────────────────────────────────────
      # NOTE: Type field absent means this is a removal event.
      # ────────────────────────────────────────────────────────────────────────
      removed: (.type == null)
    }
  | "\(.id) \(.mute) \(.removed)"
'
while read -r id mute removed; do
  if [[ "$removed" == "true" ]]; then
    unset "mutes[$id]"
  elif [[ "$mute" != "null" ]]; then
    mutes[$id]="$mute"
  fi

  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Recompute aggregate from in-memory state.
  # ────────────────────────────────────────────────────────────────────────
  muted=true
  for _muted in "${mutes[@]}"; do
    if [[ "$_muted" == "false" ]]; then
      muted=false
      break
    fi
  done

  # ────────────────────────────────────────────────────────────────────────
  # NOTE: Toggle the led indicator on MIC_MUTE button.
  # ────────────────────────────────────────────────────────────────────────
  if [[ "$muted" == true ]]; then
    brightnessctl -d "platform::micmute" set 1 &>/dev/null || true
    echo "<6>All recording devices have been muted (turn on microphone privacy indicator)."
  else
    brightnessctl -d "platform::micmute" set 0 &>/dev/null || true
    echo "<6>At least one recording device is listening (turn off microphone privacy indicator)."
  fi
done < <(pw-dump --no-colors --monitor | jq --unbuffered -r "$extract")
