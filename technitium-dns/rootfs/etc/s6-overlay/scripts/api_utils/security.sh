#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Security-related functions for API utilities
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Security Functions
# -----------------------------------------------------------------------------
# Encrypt API token for secure storage
api_encrypt_token() {
    local token="${1}"
    echo "${token}" | openssl enc -aes-256-cbc -pbkdf2 -a -salt -pass pass:"${ADDON_TOKEN_NAME}" 2>/dev/null
}

# Decrypt API token from secure storage
api_decrypt_token() {
    local encrypted="${1}"
    local decrypted

    if ! decrypted=$(echo "${encrypted}" | openssl enc -aes-256-cbc -pbkdf2 -a -d -salt -pass pass:"${ADDON_TOKEN_NAME}" 2>/dev/null); then
        bashio::log.debug "api_utils: Decryption failed"
        return 1
    fi

    echo "${decrypted}"
    return 0
}

# Redact sensitive information from URLs for logging
api_redact_url() {
    local url="${1}"
    local redacted_url

    # Replace token and password values with REDACTED
    redacted_url=$(echo "${url}" | sed -E 's/([?&])(token|pass)=[^&]*/\1\2=REDACTED/g')

    echo "${redacted_url}"
}
