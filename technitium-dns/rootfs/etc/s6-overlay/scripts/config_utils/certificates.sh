#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Certificate Path Resolution Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Certificate Paths Resolution
# -----------------------------------------------------------------------------
# Determine the paths to the certificate and key files
config_get_cert_paths() {
    local CERT_FILE=""
    local KEY_FILE=""

    # Validate certificate file
    if bashio::config.exists 'certfile' && bashio::config.has_value 'certfile'; then
        CERT_FILE="$(bashio::config 'certfile')"
        if [[ ! -f "${CERT_FILE}" || ! -r "${CERT_FILE}" ]]; then
            bashio::log.debug "config_utils: Configured certificate file not found or not readable: ${CERT_FILE}"
            CERT_FILE=""
        else
            bashio::log.debug "config_utils: Using configured certificate file: ${CERT_FILE}"
        fi
    else
        bashio::log.debug "config_utils: No certificate file configured"
        CERT_FILE=""
    fi

    # Try the Home Assistant SSL directory if primary cert file not available
    if [[ -z "${CERT_FILE}" && -f "/ssl/fullchain.pem" && -r "/ssl/fullchain.pem" ]]; then
        CERT_FILE="/ssl/fullchain.pem"
        bashio::log.debug "config_utils: Using Home Assistant SSL certificate: ${CERT_FILE}"
    fi

    # Fall back to default SSL directory if needed
    if [[ -z "${CERT_FILE}" ]]; then
        CERT_FILE="/config/ssl/fullchain.pem"
        bashio::log.debug "config_utils: Using default certificate location: ${CERT_FILE}"
    fi

    # Validate key file
    if bashio::config.exists 'keyfile' && bashio::config.has_value 'keyfile'; then
        KEY_FILE="$(bashio::config 'keyfile')"
        if [[ ! -f "${KEY_FILE}" || ! -r "${KEY_FILE}" ]]; then
            bashio::log.debug "config_utils: Configured key file not found or not readable: ${KEY_FILE}"
            KEY_FILE=""
        else
            bashio::log.debug "config_utils: Using configured key file: ${KEY_FILE}"
        fi
    else
        bashio::log.debug "config_utils: No key file configured"
        KEY_FILE=""
    fi

    # Try the Home Assistant SSL directory if primary key file not available
    if [[ -z "${KEY_FILE}" && -f "/ssl/privkey.pem" && -r "/ssl/privkey.pem" ]]; then
        KEY_FILE="/ssl/privkey.pem"
        bashio::log.debug "config_utils: Using Home Assistant SSL key: ${KEY_FILE}"
    fi

    # Fall back to default SSL directory if needed
    if [[ -z "${KEY_FILE}" ]]; then
        KEY_FILE="/config/ssl/privkey.pem"
        bashio::log.debug "config_utils: Using default key location: ${KEY_FILE}"
    fi

    echo "${CERT_FILE}|${KEY_FILE}"
}
