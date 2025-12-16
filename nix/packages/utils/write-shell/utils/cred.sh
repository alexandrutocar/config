__cred_credentials_directory_checked="no"

# Validate that credentials directory exists and is accessible
# Exits with code 1 if validation fails

if ! declare -F __cred_credentials_directory >/dev/null; then

  # shellcheck disable=SC2329
  __cred_credentials_directory() {
    if [[ "${__cred_credentials_directory_checked}" == "yes" ]]; then
      return 0
    fi

    if [[ -z "${CREDENTIALS_DIRECTORY:-}" ]]; then
      log3 "CREDENTIALS_DIRECTORY environment variable not set"
      exit 1
    fi

    if [[ ! -d "${CREDENTIALS_DIRECTORY}" ]]; then
      log3 "Credentials directory does not exist: ${CREDENTIALS_DIRECTORY}"
      exit 1
    fi

    if [[ ! -r "${CREDENTIALS_DIRECTORY}" ]]; then
      log3 "Credentials directory not readable: ${CREDENTIALS_DIRECTORY}"
      exit 1
    fi

    __cred_credentials_directory_checked="yes"
    return 0
  }

fi

# Load a credential from systemd credentials directory into an environment variable
# Args:
#   $1 - Whether to read credential or only set its path (read|path).
#   $2 - Target environment variable name
#   $3 - Credential name (filename in CREDENTIALS_DIRECTORY)
#   $4 - (Optional) Exit code on failure (default: 1)
# Returns:
#   0 on success, exits with specified code on failure
if ! declare -F cred >/dev/null; then

  # shellcheck disable=SC2329
  cred() {
    # Make sure that whatever script relies on reading credentials
    # has access to the $CREDENTIALS_DIRECTORY or that it is actually
    # provided by systemd.
    __cred_credentials_directory

    local type="$1"
    local name="$2"
    local cred="$3"
    local exit="${4:-1}"

    # Environment variable not set, try loading from credential file
    local path="${CREDENTIALS_DIRECTORY}/${cred}"

    if [[ ! -f "${path}" ]]; then
      log3 "Credential not found: ${cred}."
      exit "${exit}"
    fi

    if [[ ! -r "${path}" ]]; then
      log3 "Credential not readable: ${cred}."
      exit "${exit}"
    fi

    case "$type" in
      path)
        export "${name?}=${path}"
        log7 "Loaded credential: ${name} <- ${path}."
        return 0
        ;;

      read)
        # Read credential and export to specified variable name
        printf -v "${name}" '%s' "$( < "$path" )"
        export "${name?}"

        log7 "Loaded credential: ${name} <- ${cred}."
        return 0
        ;;

      *)
        log3 "Provided incorrect type: ${type}."
        exit "${exit}"
        ;;

    esac
  }
  
fi
