__logs_do_not_log_is_empty_warned="no"

if ! declare -F __logs_do_not_log_is_empty >/dev/null; then

  # shellcheck disable=SC2329
  __logs_do_not_log_is_empty() {
    if [[ "${__logs_do_not_log_is_empty_warned}" == "yes" ]]; then
      return 0
    fi

    local tid
    tid="$(basename "${BASH_SOURCE[0]}")"

    # Checl if
    if ! declare -p DO_NOT_LOG &>/dev/null || [[ ${#DO_NOT_LOG[@]} -eq 0 ]]; then
      logger -t "$tid" -s -p user.warning "Redaction list is empty, are you sure there is no sensitive information to redact?"
    fi

    __logs_do_not_log_is_empty_warned="yes"
  }

fi

if ! declare -F __logs_log >/dev/null; then

  # shellcheck disable=SC2329
  __logs_log() {
    # Make sure the user has been warned about
    # an empty no-logging list.
    __logs_do_not_log_is_empty

    local tid
  	local lvl="$1"
    local msg="$2"

    tid="$(basename "${BASH_SOURCE[0]}")"

    # Define variables you want to redact (global scope)
    redaction=""

    # Build the sed command dynamically
    for key in "${DO_NOT_LOG[@]}"; do
        # Only build the substitution pattern if the key is non-empty
        if [[ -n "$key" ]]; then
            # Escape sed delimiters (using #) if they appear in the key
    		# shellcheck disable=SC2001
            safe=$(echo "$key" | sed 's/[^a-zA-Z0-9]/\\&/g')
            redaction+="s#$safe#[REDACTED]#g;"
        fi
    done

    if [[ -n "$redaction" ]]; then
        # The -p flag specifies the priority (e.g., user.info, user.err)
        echo "$msg" | sed "$redaction" | logger -t "$tid" -s -p "user.$lvl"
    else
        # Pipe to logger
        logger -t "$tid" -s -p "user.$lvl" "$msg"
    fi
  }

fi

if ! declare -F log3 >/dev/null; then

  # shellcheck disable=SC2329
  log3() {
    __logs_log "err" "$1"
  }

fi

if ! declare -F log6 >/dev/null; then

  # shellcheck disable=SC2329
  log6() {
  	__logs_log "info" "$1"
  }

fi

if ! declare -F log7 >/dev/null; then

  # shellcheck disable=SC2329
  log7() {
  	__logs_log "debug" "$1"
  }

fi
