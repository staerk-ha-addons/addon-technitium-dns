#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Technitium DNS Server Add-on: Utility Orchestration
#
# This script serves as the central orchestration point for all utility modules,
# ensuring consistent loading order and proper dependency management across the
# add-on's component scripts. It provides a single import point for other scripts
# that need access to the full suite of utility functions.
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Module Dependencies
# -----------------------------------------------------------------------------
# Load configuration utilities which handle user settings and environment configuration
# shellcheck source=rootfs/etc/s6-overlay/scripts/config_utils.sh
source /etc/s6-overlay/scripts/config_utils.sh

# Load certificate utilities for SSL/TLS certificate management
# shellcheck source=rootfs/etc/s6-overlay/scripts/cert_utils.sh
source /etc/s6-overlay/scripts/cert_utils.sh

# Load API interaction utilities for communicating with the DNS server
# shellcheck source=rootfs/etc/s6-overlay/scripts/api_utils.sh
source /etc/s6-overlay/scripts/api_utils.sh

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------
# Log successful initialization of utility modules
bashio::log.trace "all_utils: All utility modules loaded successfully"

# Register cleanup handler for graceful shutdown
trap cleanup EXIT INT TERM HUP

# -----------------------------------------------------------------------------
# Cleanup Handler
# -----------------------------------------------------------------------------
# Ensure proper cleanup when script terminates
all_cleanup() {
    bashio::log.trace "all_utils: Performing cleanup operations"

    # Each module has its own cleanup function that will be called if defined
    if declare -f api_cleanup >/dev/null; then
        api_cleanup || true
    fi

    if declare -f cert_cleanup >/dev/null; then
        cert_cleanup || true
    fi

    if declare -f dns_cleanup >/dev/null; then
        dns_cleanup || true
    fi

    # Remove any temporary files or locks
    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}
