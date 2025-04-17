#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# OpenSSL Command Wrapper and Utilities
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# OpenSSL Command Wrapper
# -----------------------------------------------------------------------------
# Execute OpenSSL commands with timeout and standardized error handling
cert_openssl_command() {
    # Prevents command execution from hanging indefinitely
    local timeout_seconds=30
    local cmd=("$@")

    # Use timeout command to prevent hanging
    if ! timeout "${timeout_seconds}" "${cmd[@]}"; then
        bashio::log.error "cert_utils: OpenSSL command failed or timed out: ${cmd[*]}"
        return 1
    fi

    # Command executed successfully
    return 0
}

# -----------------------------------------------------------------------------
# Extract Certificate Data
# -----------------------------------------------------------------------------
# Extract certificate data from PKCS12 file
cert_extract_cert_data() {
    if [[ ! -f "${ADDON_PKCS12_FILE}" ]]; then
        return 1
    fi

    cert_openssl_command openssl pkcs12 -in "${ADDON_PKCS12_FILE}" -nokeys -passin pass:"${ADDON_PKCS12_PASSWORD}" 2>/dev/null
    return $?
}
