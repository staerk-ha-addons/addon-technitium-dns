#!/command/with-contenv bashio
# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Home Assistant Add-on: Technitium DNS
# Environment variable utilities
# -----------------------------------------------------------------------------

# Enable strict mode
set -o nounset -o errexit -o pipefail

# Function to write environment variables
# Arguments:
#   $1 - Variable name
#   $2 - Variable value
function write_env() {
    local name="${1}"
    local value="${2}"

    bashio::log.debug "write_env: ${name}=${value}"
    printf '%s' "${value}" >"/run/s6/container_environment/${name}"
}

