# Constants
TIME="$(date --utc +%Y%m%d%H%M%S)"
WEEK=7
YEAR=12

# Cleanup
# shellcheck disable=SC2329
cleanup() {
  rm -f "/tmp/davis.${TIME}.dump"
}

trap cleanup EXIT

log6 "Starting backup for database: davis..."

# Initialize Restic repository if it does not exist
# Args:
#   $1 - (Optional) Exit code on failure (default: 2)
# Returns:
#   0 if repository exists or was initialized successfully
__01_init() {
  local exit="${1:-2}"
  log6 "Checking Restic repository status..."
  if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    log3 "RESTIC_REPOSITORY not set."
    exit "${exit}"
  fi
  if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
    log3 "RESTIC_PASSWORD not set."
    exit "${exit}"
  fi
  # Check if repository exists by attempting to list snapshots
  if restic snapshots &>/dev/null; then
    log6 "Repository already exists and is accessible."
    return 0
  fi
  log6 "Repository not found or inaccessible, initializing..."
  if ! restic init; then
    log3  "Failed to initialize Restic repository."
    exit "${exit}"
  fi
  log6 "Repository initialized successfully."
}


# Create a PostgreSQL dump suitable for Restic backup
# Args:
#   $1 - (Optional) Exit code on failure (default: 3)
# Returns:
#   0 on success, exits with specified code on failure
__02_dump() {
  local name="davis"
  local file="/tmp/davis.${TIME}.dump"
  local exit="${1:-3}"
  log6 "Creating database dump for: ${name}..."
  # (1) Use custom format for efficient compression and selective restoration.
  # (2) Disable built-in compression of pg_dump as Restic will handle the compression.
  if ! pg_dump "${name}" --format=custom --compress=0 > "${file}"; then
    rm -f "${file}"
    log3 "Database dump failed for: ${name}"
    exit "${exit}"
  fi
  log6 "Database dump created successfully: ${file}"
}


# Prune old Restic backups according to retention policy
# Args:
#   $1 - (Optional) Exit code on failure (default: 5)
# Returns:
#   0 on success, exits with specified code on failure
__03_back() {
  local dump="/tmp/davis.${TIME}.dump"
  local file="davis.${TIME}.dump"
  local exit="${1:-5}"
  log6 "Uploading backup to repository: ${file}..."
  if ! restic backup \
      --compression=max \
      --stdin \
      --stdin-filename="${file}" \
      < "${dump}"; then
    log3 "Backup upload failed." && exit "${exit}"
  fi
  log6 "Backup uploaded successfully"
}


# Prune old Restic backups according to retention policy
# Args:
#   $1 - Weekly retention count
#   $2 - Yearly retention count
#   $3 - (Optional) Exit code on failure (default: 5)
# Returns:
#   0 on success, exits with specified code on failure
__04_tidy() {
  local week="$1"
  local year="$2"
  local exit="${3:-5}"
  log6 "Pruning old backups (weekly=${week}, yearly=${year})..."
  if ! restic forget \
      --keep-weekly="${week}" \
      --keep-yearly="${year}" \
      --prune; then
    log3 "Pruning failed."
    exit "${exit}"
  fi
  log6 "Pruning completed successfully."
}


__01_init
__02_dump
__03_back
__04_tidy "${WEEK}" "${YEAR}"


log "Backup operation completed successfully."
exit 0
