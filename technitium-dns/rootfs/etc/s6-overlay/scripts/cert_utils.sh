#!/command/with-contenv bashio
# shellcheck shell=bash
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

# -----------------------------------------------------------------------------
# Constants and Configuration
# -----------------------------------------------------------------------------
readonly DEFAULT_CERT="/config/ssl/fullchain.pem"
readonly DEFAULT_KEY="/config/ssl/privkey.key"
readonly DEFAULT_HOSTNAME="homeassistant.local"
readonly PKCS12_PASSWORD="TechnitiumDNS!SSL"
readonly PKCS12_FILE="/config/ssl/technitium.pfx"
readonly SSL_DIR="/config/ssl"

# Dynamic configuration
CERT_FILE=""
KEY_FILE=""
HOSTNAME=""

# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------
init_configuration() {
    # Set hostname
    HOST_SYSTEM_HOSTNAME=$(bashio::info.hostname)
    HOSTNAME=${HOST_SYSTEM_HOSTNAME:-$DEFAULT_HOSTNAME}

    # Create SSL directory if needed
    if [ ! -d "$SSL_DIR" ]; then
        mkdir -p "$SSL_DIR"
    fi

    # Get certificate paths with defaults
    CERT_FILE=$(bashio::config 'certfile' "$DEFAULT_CERT")
    KEY_FILE=$(bashio::config 'keyfile' "$DEFAULT_KEY")
}

# -----------------------------------------------------------------------------
# Certificate Validation Functions
# -----------------------------------------------------------------------------
check_pkcs12() {
    local expiry_date

    if [ ! -f "$PKCS12_FILE" ]; then
        bashio::log.debug "No PKCS12 file found"
        return 1
    fi

    # Validate PKCS12 format
    if ! openssl pkcs12 -in "$PKCS12_FILE" -noout -passin pass:"$PKCS12_PASSWORD" 2>/dev/null; then
        bashio::log.debug "Invalid PKCS12 file"
        return 1
    fi

    # Check expiration
    expiry_date=$(openssl pkcs12 -in "$PKCS12_FILE" -nokeys -passin pass:"$PKCS12_PASSWORD" 2>/dev/null |
        openssl x509 -noout -enddate | cut -d'=' -f2)

    if openssl pkcs12 -in "$PKCS12_FILE" -nokeys -passin pass:"$PKCS12_PASSWORD" 2>/dev/null |
        openssl x509 -noout -checkend 0 2>/dev/null; then
        bashio::log.debug "Valid non-expired PKCS12 file found (expires: ${expiry_date})"
        return 0
    else
        bashio::log.debug "PKCS12 certificate is expired (expired: ${expiry_date})"
        return 1
    fi
}

check_cert_paths() {
    # Validate certificate file
    if [ ! -f "$CERT_FILE" ] || [ ! -r "$CERT_FILE" ]; then
        bashio::log.debug "Certificate file not found or not readable, using default: $DEFAULT_CERT"
        CERT_FILE="$DEFAULT_CERT"
    else
        bashio::log.debug "Using certificate file: $CERT_FILE"
    fi

    # Validate key file
    if [ ! -f "$KEY_FILE" ] || [ ! -r "$KEY_FILE" ]; then
        bashio::log.debug "Key file not found or not readable, using default: $DEFAULT_KEY"
        KEY_FILE="$DEFAULT_KEY"
    else
        bashio::log.debug "Using key file: $KEY_FILE"
    fi
}

# -----------------------------------------------------------------------------
# Certificate Generation Functions
# -----------------------------------------------------------------------------
generate_self_signed() {
    bashio::log.debug "Generating self-signed certificate..."
    openssl req -x509 \
        -newkey rsa:4096 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days 365 \
        -nodes \
        -subj "/CN=$HOSTNAME"
}

generate_pkcs12() {
    bashio::log.debug "Generating PKCS12 file..."
    openssl pkcs12 -export \
        -out "$PKCS12_FILE" \
        -inkey "$KEY_FILE" \
        -in "$CERT_FILE" \
        -password pass:"$PKCS12_PASSWORD"
}

# Add certificate cleanup
cleanup_certs() {
    # Remove sensitive files
    rm -f "${PKCS12_FILE}.tmp" 2>/dev/null || true
}

trap cleanup_certs EXIT

# -----------------------------------------------------------------------------
# Main Certificate Management Function
# -----------------------------------------------------------------------------
handle_cert_update() {
    bashio::log.debug "Checking certificate status..."

    # Initialize configuration
    init_configuration

    # Validate paths
    check_cert_paths

    local regenerate_pkcs12=false

    # Check if we need to generate certificates
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        bashio::log.debug "Certificate files are not present - generating self-signed certificates..."
        generate_self_signed
        regenerate_pkcs12=true
    fi

    # Update PKCS12 if needed
    if [ "$regenerate_pkcs12" = "true" ] || ! check_pkcs12; then
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
