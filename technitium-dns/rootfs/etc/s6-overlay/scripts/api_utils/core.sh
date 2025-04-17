#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Core functionality for API utilities
# ==============================================================================
set -o nounset -o errexit -o pipefail

if [[ "${DEBUG:-false}" == "true" ]]; then
    bashio::log.level 'debug'
fi

# -----------------------------------------------------------------------------
# Environment Variable Check
# -----------------------------------------------------------------------------
# Ensure required environment variables are set before proceeding
required_env_vars=("ADDON_API_SERVER" "ADDON_TOKEN_NAME" "ADDON_TOKEN_FILE" "ADDON_LOCK_FILE" "ADDON_DOMAIN")

for var in "${required_env_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        bashio::log.error "api_utils: Required environment variable ${var} is not set!"
        exit 1
    fi
done

bashio::log.trace "api_utils: All required environment variables present"

# -----------------------------------------------------------------------------
# File Lock Management
# -----------------------------------------------------------------------------
# Acquire a file lock for operations requiring exclusivity
api_acquire_lock() {
    exec 200>"${ADDON_LOCK_FILE}"
    if flock -n 200; then
        return 0
    else
        bashio::log.warning "api_utils: Could not acquire lock"
        return 1
    fi
}

# Release a previously acquired lock
api_release_lock() {
    flock -u 200
    exec 200>&-
    return 0
}

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
# Handle cleanup duties for script termination
api_cleanup() {
    # Close and release any open file descriptors
    local fd
    for fd in {200..210}; do
        if [[ -e /proc/$$/fd/${fd} ]]; then
            eval "exec ${fd}>&-" 2>/dev/null || true
        fi
    done

    # Remove lock file
    if [[ -f "${ADDON_LOCK_FILE}" ]]; then
        rm -f "${ADDON_LOCK_FILE}" 2>/dev/null || true
    fi

    bashio::log.debug "api_utils: Cleanup completed"
}
