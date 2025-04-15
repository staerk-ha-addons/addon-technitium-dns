#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091
# ==============================================================================
# Certificate Management Utilities for Technitium DNS Server
# ==============================================================================

# -----------------------------------------------------------------------------
# Dependency Check
# -----------------------------------------------------------------------------
if ! command -v openssl >/dev/null 2>&1; then
    bashio::log.debug "openssl binary not found!"
    exit 1
fi

# Source helper utilities
# shellcheck source=/etc/s6-overlay/scripts/helper_utils.sh
if ! source "/etc/s6-overlay/scripts/helper_utils.sh"; then
    bashio::exit.nok "Failed to source helper utilities"
fi

# -----------------------------------------------------------------------------
# Constants and Configuration
# -----------------------------------------------------------------------------
readonly CONFIG_SSL_DIR="/config/ssl"
readonly PKCS12_FILE="${CONFIG_SSL_DIR}/technitium.pfx"
readonly PKCS12_PASSWORD="TechnitiumDNS!SSL"

# Dynamic configuration
CERT_FILE=""
KEY_FILE=""

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------
init_configuration() {
    # Create SSL directory if needed
    if [[ ! -d "${CONFIG_SSL_DIR}" ]]; then
        mkdir -p "${CONFIG_SSL_DIR}"
    fi

    check_cert_paths
}

# -----------------------------------------------------------------------------
# Certificate Validation Functions
# -----------------------------------------------------------------------------
check_pkcs12() {
    local expiry_date

    if [[ ! -f "${PKCS12_FILE}" ]]; then
        bashio::log.debug "No PKCS12 file found"
        return 1
    fi

    # Validate PKCS12 format
    if ! openssl pkcs12 -in "${PKCS12_FILE}" -noout -passin pass:"${PKCS12_PASSWORD}" 2>/dev/null; then
        bashio::log.debug "Invalid PKCS12 file"
        return 1
    fi

    # Extract expiration date
    local cert_data
    cert_data=$(openssl pkcs12 -in "${PKCS12_FILE}" -nokeys -passin pass:"${PKCS12_PASSWORD}" 2>/dev/null || true)

    # Now extract expiry date from cert data
    if [[ -n "${cert_data}" ]]; then
        local expiry_output
        expiry_output=$(echo "${cert_data}" | openssl x509 -noout -enddate || true)
        expiry_date=$(echo "${expiry_output}" | cut -d'=' -f2)

        # Check certificate validity separately to avoid masking return value
        echo "${cert_data}" | openssl x509 -noout -checkend 0 >/dev/null 2>&1
        local valid=$?

        if [[ ${valid} -eq 0 ]]; then
            bashio::log.debug "Valid non-expired PKCS12 file found (expires: ${expiry_date})"
            return 0
        else
            bashio::log.debug "PKCS12 certificate is expired (expired: ${expiry_date})"
            return 1
        fi
    else
        bashio::log.debug "Failed to extract certificate data"
        return 1
    fi
}

check_cert_paths() {
    # Validate certificate file
    if bashio::config.exists 'certfile' && bashio::config.has_value 'certfile'; then
        CERT_FILE="$(bashio::config 'certfile')"
        if [[ ! -f "${CERT_FILE}" || ! -r "${CERT_FILE}" ]]; then
            bashio::log.debug "Configured certificate file not found or not readable: ${CERT_FILE}"
            CERT_FILE=""
        else
            bashio::log.debug "Using configured certificate file: ${CERT_FILE}"
        fi
    else
        bashio::log.debug "No certificate file configured"
        CERT_FILE=""
    fi

    # Try the Home Assistant SSL directory if primary cert file not available
    if [[ -z "${CERT_FILE}" && -f "/ssl/fullchain.pem" && -r "/ssl/fullchain.pem" ]]; then
        CERT_FILE="/ssl/fullchain.pem"
        bashio::log.debug "Using Home Assistant SSL certificate: ${CERT_FILE}"
    fi

    # Fall back to default SSL directory if needed
    if [[ -z "${CERT_FILE}" ]]; then
        CERT_FILE="${CONFIG_SSL_DIR}/fullchain.pem"
        bashio::log.debug "Using default certificate location: ${CERT_FILE}"
    fi

    # Validate key file
    if bashio::config.exists 'keyfile' && bashio::config.has_value 'keyfile'; then
        KEY_FILE="$(bashio::config 'keyfile')"
        if [[ ! -f "${KEY_FILE}" || ! -r "${KEY_FILE}" ]]; then
            bashio::log.debug "Configured key file not found or not readable: ${KEY_FILE}"
            KEY_FILE=""
        else
            bashio::log.debug "Using configured key file: ${KEY_FILE}"
        fi
    else
        bashio::log.debug "No key file configured"
        KEY_FILE=""
    fi

    # Try the Home Assistant SSL directory if primary key file not available
    if [[ -z "${KEY_FILE}" && -f "/ssl/privkey.pem" && -r "/ssl/privkey.pem" ]]; then
        KEY_FILE="/ssl/privkey.pem"
        bashio::log.debug "Using Home Assistant SSL key: ${KEY_FILE}"
    fi

    # Fall back to default SSL directory if needed
    if [[ -z "${KEY_FILE}" ]]; then
        KEY_FILE="${CONFIG_SSL_DIR}/privkey.pem"
        bashio::log.debug "Using default key location: ${KEY_FILE}"
    fi
}

# -----------------------------------------------------------------------------
# Certificate Hostname Validation
# -----------------------------------------------------------------------------
check_hostname_match() {
    local cert_cn
    local cert_sans
    local hostname_match=false
    local current_hostname
    current_hostname=$(get_hostname)

    # Skip if PKCS12 file doesn't exist or is invalid
    if [[ ! -f "${PKCS12_FILE}" ]]; then
        bashio::log.debug "No PKCS12 file exists yet for hostname validation"
        return 1
    fi

    # Extract certificate data
    local cert_data
    cert_data=$(openssl pkcs12 -in "${PKCS12_FILE}" -nokeys -passin pass:"${PKCS12_PASSWORD}" 2>/dev/null || true)

    if [[ -z "${cert_data}" ]]; then
        bashio::log.debug "Cannot extract certificate data for hostname validation"
        return 1
    fi

    # Get the certificate's Common Name (CN)
    local subject_output
    subject_output=$(echo "${cert_data}" | openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null || true)
    cert_cn=$(echo "${subject_output}" | sed -n 's/.*CN=\([^,]*\).*/\1/p' || true)

    # Get all Subject Alternative Names (SANs)
    local sans_output
    sans_output=$(echo "${cert_data}" | openssl x509 -noout -ext subjectAltName 2>/dev/null || true)
    cert_sans=$(echo "${sans_output}" | grep -o "DNS:[^,]*" | sed 's/DNS://g' || true)

    bashio::log.debug "Certificate CN: ${cert_cn}"
    bashio::log.debug "Certificate SANs: ${cert_sans}"
    bashio::log.debug "Current hostname: ${current_hostname}"

    # Check if current hostname matches CN
    if [[ "${cert_cn}" == "${current_hostname}" ]]; then
        bashio::log.debug "Hostname matches certificate CN"
        hostname_match=true
    fi

    # Check if current hostname matches any SAN
    if [[ "${hostname_match}" == "false" ]] && [[ -n "${cert_sans}" ]]; then
        # Process each SAN using a process substitution instead of a pipeline
        while read -r san; do
            if [[ "${san}" == "${current_hostname}" ]]; then
                bashio::log.debug "Hostname matches certificate SAN: ${san}"
                hostname_match=true
                break
            fi
        done < <(echo "${cert_sans}")
    fi

    if [[ "${hostname_match}" == "true" ]]; then
        bashio::log.debug "Certificate valid for current hostname"
        return 0
    else
        bashio::log.debug "Certificate NOT valid for current hostname - regeneration required"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Certificate Generation Functions
# -----------------------------------------------------------------------------
generate_self_signed() {
    local hostname
    hostname=$(get_hostname)

    bashio::log.debug "Generating self-signed certificate for hostname: ${hostname}"
    openssl req -x509 \
        -newkey rsa:4096 \
        -keyout "${KEY_FILE}" \
        -out "${CERT_FILE}" \
        -days 365 \
        -nodes \
        -subj "/CN=${hostname}"
}

generate_pkcs12() {
    bashio::log.debug "Generating PKCS12 file..."
    openssl pkcs12 -export \
        -out "${PKCS12_FILE}" \
        -inkey "${KEY_FILE}" \
        -in "${CERT_FILE}" \
        -password pass:"${PKCS12_PASSWORD}"
}

# -----------------------------------------------------------------------------
# Main Certificate Management Function
# -----------------------------------------------------------------------------
handle_cert_update() {
    bashio::log.debug "Checking certificate status..."

    # Initialize configuration
    init_configuration

    local regenerate_pkcs12=false
    local need_pkcs12=false

    # Check if we need to generate certificates
    if [[ ! -f "${CERT_FILE}" || ! -f "${KEY_FILE}" ]]; then
        bashio::log.debug "Certificate files are not present - generating self-signed certificates..."
        generate_self_signed
        regenerate_pkcs12=true
    fi

    # Check if hostname matches certificate
    if ! check_hostname_match; then
        bashio::log.debug "Current hostname doesn't match certificate - regenerating"
        generate_self_signed
        regenerate_pkcs12=true
    fi

    # Update PKCS12 if needed
    if [[ "${regenerate_pkcs12}" = "true" ]]; then
        bashio::log.debug "Regenerating PKCS12 due to regenerate flag or hostname mismatch"
        need_pkcs12=true
    else
        # Run check_pkcs12 and check its return status directly
        if ! check_pkcs12; then
            bashio::log.debug "Regenerating PKCS12 due to validation failure"
            need_pkcs12=true
        else
            need_pkcs12=false
        fi
    fi

    if [[ "${need_pkcs12}" = "true" ]]; then
        if generate_pkcs12; then
            bashio::log.debug "PKCS12 certificate generated successfully"
        else
            bashio::log.debug "Failed to generate PKCS12 certificate"
            return 1
        fi
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Initialize Configuration
# -----------------------------------------------------------------------------
init_configuration

# -----------------------------------------------------------------------------
# Documentation References
# -----------------------------------------------------------------------------
# https://www.home-assistant.io/docs/configuration/securing/
# https://developers.home-assistant.io/docs/add-ons/configuration#add-on-configuration
# https://blog.technitium.com/2020/07/how-to-host-your-own-dns-over-https-and.html
