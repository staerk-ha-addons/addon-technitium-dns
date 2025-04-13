#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Shared certificate utilities for Technitium DNS Server add-on
# ==============================================================================

# Set default paths
DEFAULT_CERTFILE="/config/ssl/fullchain.pem"
DEFAULT_KEYFILE="/config/ssl/privkey.pem"
CERTFILE="${DEFAULT_CERTFILE}"
KEYFILE="${DEFAULT_KEYFILE}"
PKCS12FILE="$(bashio::config 'pkcs12file' '/config/ssl/technitium.pfx')"
PASSWORD="$(bashio::config 'ssl_pfx_password')"

# Check if OpenSSL is available
if ! command -v openssl >/dev/null 2>&1; then
    bashio::log.error "OpenSSL is not installed"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    bashio::log.warning "No SSL PFX password set - using default password. This is not recommended for production use."
    PASSWORD="TechnitiumDNS!SSL"
fi

# First check if certfile and keyfile are configured
if bashio::config.has_value 'certfile' && bashio::config.has_value 'keyfile'; then
    CERTFILE="$(bashio::config 'certfile' '/ssl/fullchain.pem')"
    KEYFILE="$(bashio::config 'keyfile' '/ssl/privkey.pem')"
    
    # Check if the directories exist
    if ! bashio::fs.directory_exists "$(dirname "${CERTFILE}")" || \
       ! bashio::fs.directory_exists "$(dirname "${KEYFILE}")"; then
        bashio::log.warning "Certificate directories do not exist - using defaults"
        CERTFILE="/config/ssl/fullchain.pem"
        KEYFILE="/config/ssl/privkey.pem"
    # Check if the files exist
    elif ! bashio::fs.file_exists "${CERTFILE}" || \
         ! bashio::fs.file_exists "${KEYFILE}"; then
        bashio::log.warning "Certificate files do not exist - using defaults"
        CERTFILE="/config/ssl/fullchain.pem"
        KEYFILE="/config/ssl/privkey.pem"
    else
        bashio::log.info "Using configured certificates"
    fi
else
    bashio::log.info "No certificate configuration found - using defaults"
    CERTFILE="/config/ssl/fullchain.pem"
    KEYFILE="/config/ssl/privkey.pem"
fi

# Ensure /config/ssl exists if we're using it
if [[ $CERTFILE == /config/ssl/* ]] || [[ $KEYFILE == /config/ssl/* ]] || [[ $PKCS12FILE == /config/ssl/* ]]; then
    if ! bashio::fs.directory_exists "/config/ssl"; then
        bashio::log.info "Creating /config/ssl directory"
        mkdir -p /config/ssl || {
            bashio::log.error "Failed to create /config/ssl directory"
            exit 1
        }
    fi
fi

# Check if certificate expires within 30 days
if ! openssl x509 -checkend 2592000 -noout -in <(openssl pkcs12 -in "$PKCS12FILE" -nokeys -passin "pass:${PASSWORD}" 2>/dev/null | openssl x509); then
    bashio::log.warning "Certificate will expire within 30 days"
    generate_cert
fi

generate_self_signed_cert() {
    bashio::log.warning "Generating self-signed certificate as fallback..."
    local selfsigned_cert="/config/ssl/selfsigned.pem"
    local selfsigned_key="/config/ssl/selfsigned.key"
    local hostname
    hostname="$(bashio::info.hostname)"

    if openssl req -x509 -newkey rsa:2048 -keyout "$selfsigned_key" -out "$selfsigned_cert" -days 365 -nodes \
        -subj "/CN=${hostname}"; then
        bashio::log.info "Successfully generated self-signed certificate"
        CERTFILE="$selfsigned_cert"
        KEYFILE="$selfsigned_key"
    else
        bashio::log.error "Failed to generate self-signed certificate"
    fi
}

generate_cert() {
    bashio::log.info "Generating new PKCS #12 certificate..."
    if openssl pkcs12 -export \
        -out "$PKCS12FILE" \
        -inkey "$KEYFILE" \
        -in "$CERTFILE" \
        -passout "pass:${PASSWORD}"; then
        bashio::log.info "Successfully generated PKCS #12 certificate at $PKCS12FILE"
    else
        bashio::log.error "Failed to generate PKCS #12 certificate"
    fi
}

check_and_generate() {
    if ! bashio::fs.file_exists "$CERTFILE" || ! bashio::fs.file_exists "$KEYFILE"; then
        bashio::log.warning "Certificate files missing — generating self-signed certificate as fallback"
        generate_self_signed_cert
    fi

    if bashio::fs.file_exists "$PKCS12FILE"; then
        local EXPIRY
        EXPIRY="$(openssl pkcs12 -in "$PKCS12FILE" -nokeys -passin "pass:${PASSWORD}" 2>/dev/null \
            | openssl x509 -noout -enddate \
            | cut -d= -f2)"

        if [ -n "$EXPIRY" ]; then
            bashio::log.info "Existing PKCS #12 certificate expires on: $EXPIRY"

            if openssl x509 -checkend 0 -noout -in <(openssl pkcs12 -in "$PKCS12FILE" -nokeys -passin "pass:${PASSWORD}" 2>/dev/null | openssl x509); then
                bashio::log.info "Existing PKCS #12 certificate is still valid — skipping generation"
                return
            fi
        fi
    fi

    generate_cert
}
