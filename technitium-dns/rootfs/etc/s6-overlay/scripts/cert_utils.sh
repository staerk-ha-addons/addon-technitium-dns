#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Certificate Management Utilities for Technitium DNS Server
#
# This module provides functions to manage SSL certificates for the DNS server,
# including validation, generation of self-signed certificates, and conversion
# to PKCS12 format required by the Technitium DNS Server.
# ==============================================================================

if [[ "${DEBUG:-false}" == "true" ]]; then
    bashio::log.level 'debug'
fi

# -----------------------------------------------------------------------------
# Dependency Check
# -----------------------------------------------------------------------------
# Verify OpenSSL is available for certificate operations
if ! command -v openssl >/dev/null 2>&1; then
    bashio::log.error "cert_utils: OpenSSL binary not found! Certificate management requires OpenSSL."
    exit 1
fi

# -----------------------------------------------------------------------------
# Environment Variable Check
# -----------------------------------------------------------------------------
# Validate all required environment variables are set
required_env_vars=("ADDON_SSL_DIR" "ADDON_CERT_FILE" "ADDON_KEY_FILE" "ADDON_PKCS12_FILE" "ADDON_PKCS12_PASSWORD" "ADDON_DOMAIN")

for var in "${required_env_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        bashio::log.error "cert_utils: Required environment variable ${var} is not set!"
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Certificate Validation Functions
# -----------------------------------------------------------------------------
# Check if PKCS12 certificate exists and is valid
check_pkcs12() {
    local expiry_date

    # Check if the file exists
    if [[ ! -f "${ADDON_PKCS12_FILE}" ]]; then
        bashio::log.debug "cert_utils: No PKCS12 file found at ${ADDON_PKCS12_FILE}"
        return 1
    fi

    # Validate PKCS12 format using OpenSSL
    if ! openssl pkcs12 -in "${ADDON_PKCS12_FILE}" -noout -passin pass:"${ADDON_PKCS12_PASSWORD}" 2>/dev/null; then
        bashio::log.warning "cert_utils: Invalid PKCS12 file format at ${ADDON_PKCS12_FILE}"
        return 1
    fi

    # Extract X.509 certificate from PKCS12 for validation
    local cert_data
    cert_data=$(openssl pkcs12 -in "${ADDON_PKCS12_FILE}" -nokeys -passin pass:"${ADDON_PKCS12_PASSWORD}" 2>/dev/null || true)

    # Extract expiration date from certificate data
    if [[ -n "${cert_data}" ]]; then
        # Get expiry date in human-readable format
        local expiry_output
        expiry_output=$(echo "${cert_data}" | openssl x509 -noout -enddate || true)
        expiry_date=$(echo "${expiry_output}" | cut -d'=' -f2)

        # Check if certificate is still valid (not expired)
        echo "${cert_data}" | openssl x509 -noout -checkend 0 >/dev/null 2>&1
        local valid=$?

        if [[ ${valid} -eq 0 ]]; then
            bashio::log.debug "cert_utils: Valid non-expired PKCS12 certificate (expires: ${expiry_date})"
            return 0
        else
            bashio::log.warning "cert_utils: PKCS12 certificate has expired (expired: ${expiry_date})"
            return 1
        fi
    else
        bashio::log.warning "cert_utils: Failed to extract certificate data from PKCS12 file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Certificate Hostname Validation
# -----------------------------------------------------------------------------
# Check if certificate is valid for the current hostname
check_hostname_match() {
    local cert_cn
    local cert_sans
    local hostname_match=false

    # Skip validation if PKCS12 file doesn't exist
    if [[ ! -f "${ADDON_PKCS12_FILE}" ]]; then
        bashio::log.debug "cert_utils: No PKCS12 file exists yet for hostname validation"
        return 1
    fi

    # Extract certificate data from PKCS12
    local cert_data
    cert_data=$(openssl pkcs12 -in "${ADDON_PKCS12_FILE}" -nokeys -passin pass:"${ADDON_PKCS12_PASSWORD}" 2>/dev/null || true)

    if [[ -z "${cert_data}" ]]; then
        bashio::log.warning "cert_utils: Cannot extract certificate data for hostname validation"
        return 1
    fi

    # Extract Subject Common Name (CN) from certificate
    local subject_output
    subject_output=$(echo "${cert_data}" | openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null || true)
    cert_cn=$(echo "${subject_output}" | sed -n 's/.*CN=\([^,]*\).*/\1/p' || true)

    # Extract all Subject Alternative Names (SANs) from certificate
    local sans_output
    sans_output=$(echo "${cert_data}" | openssl x509 -noout -ext subjectAltName 2>/dev/null || true)
    cert_sans=$(echo "${sans_output}" | grep -o "DNS:[^,]*" | sed 's/DNS://g' || true)

    # Log certificate details for debugging
    bashio::log.debug "cert_utils: Certificate CN: ${cert_cn}"
    bashio::log.debug "cert_utils: Certificate SANs: ${cert_sans}"
    bashio::log.debug "cert_utils: Current hostname: ${ADDON_DOMAIN}"

    # Check if current hostname matches the certificate's Common Name
    if [[ "${cert_cn}" == "${ADDON_DOMAIN}" ]]; then
        bashio::log.debug "cert_utils: Hostname matches certificate CN"
        hostname_match=true
    fi

    # Check if current hostname matches any of the Subject Alternative Names
    if [[ "${hostname_match}" == "false" ]] && [[ -n "${cert_sans}" ]]; then
        # Process each SAN using a process substitution to avoid subshell issues
        while read -r san; do
            if [[ "${san}" == "${ADDON_DOMAIN}" ]]; then
                bashio::log.debug "cert_utils: Hostname matches certificate SAN: ${san}"
                hostname_match=true
                break
            fi
        done < <(echo "${cert_sans}")
    fi

    # Return success if hostname matches certificate, otherwise failure
    if [[ "${hostname_match}" == "true" ]]; then
        bashio::log.debug "cert_utils: Certificate valid for current hostname: ${ADDON_DOMAIN}"
        return 0
    else
        bashio::log.debug "cert_utils: Certificate NOT valid for current hostname - regeneration required"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Certificate Generation Functions
# -----------------------------------------------------------------------------
# Generate a new self-signed certificate for the current hostname
generate_self_signed() {
    bashio::log.info "cert_utils: Generating self-signed certificate for hostname: ${ADDON_DOMAIN}"

    # Generate certificate with 4096-bit RSA key and 365 day validity
    if openssl req -x509 \
        -newkey rsa:4096 \
        -keyout "${ADDON_KEY_FILE}" \
        -out "${ADDON_CERT_FILE}" \
        -days 365 \
        -nodes \
        -subj "/CN=${ADDON_DOMAIN}" \
        -addext "subjectAltName=DNS:${ADDON_DOMAIN}" 2>/dev/null; then

        # Set appropriate permissions for the generated files
        chmod 600 "${ADDON_KEY_FILE}"
        chmod 644 "${ADDON_CERT_FILE}"
        bashio::log.debug "cert_utils: Self-signed certificate generated successfully"
        return 0
    else
        bashio::log.error "cert_utils: Failed to generate self-signed certificate"
        return 1
    fi
}

# Convert certificate and key to PKCS12 format for Technitium DNS Server
generate_pkcs12() {
    bashio::log.info "cert_utils: Generating PKCS12 file from certificate and key..."

    # Verify that source files exist
    if [[ ! -f "${ADDON_CERT_FILE}" ]]; then
        bashio::log.error "cert_utils: Certificate file doesn't exist: ${ADDON_CERT_FILE}"
        return 1
    fi

    if [[ ! -f "${ADDON_KEY_FILE}" ]]; then
        bashio::log.error "cert_utils: Key file doesn't exist: ${ADDON_KEY_FILE}"
        return 1
    fi

    # Create PKCS12 file from certificate and key
    if openssl pkcs12 -export \
        -out "${ADDON_PKCS12_FILE}" \
        -inkey "${ADDON_KEY_FILE}" \
        -in "${ADDON_CERT_FILE}" \
        -password pass:"${ADDON_PKCS12_PASSWORD}" 2>/dev/null; then

        # Set appropriate permissions for the generated PKCS12 file
        chmod 600 "${ADDON_PKCS12_FILE}"
        bashio::log.debug "cert_utils: PKCS12 file generated successfully: ${ADDON_PKCS12_FILE}"
        return 0
    else
        bashio::log.error "cert_utils: Failed to generate PKCS12 file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Main Certificate Management Function
# -----------------------------------------------------------------------------
# Handle certificate updates and ensure valid certificates are available
handle_cert_update() {
    bashio::log.info "cert_utils: Checking certificate status..."

    # Track if we need to regenerate certificates
    local regenerate_pkcs12=false
    local need_pkcs12=false

    # Check if we need to generate certificates - if either cert or key is missing
    if [[ ! -f "${ADDON_CERT_FILE}" || ! -f "${ADDON_KEY_FILE}" ]]; then
        bashio::log.info "cert_utils: Certificate or key file missing - generating self-signed certificate"
        if generate_self_signed; then
            regenerate_pkcs12=true
        else
            bashio::log.error "cert_utils: Failed to generate self-signed certificate"
            return 1
        fi
    fi

    # Check if certificate matches current hostname
    if [[ -f "${ADDON_PKCS12_FILE}" ]]; then
        if ! check_hostname_match; then
            bashio::log.info "cert_utils: Current hostname doesn't match certificate - regenerating"
            if generate_self_signed; then
                regenerate_pkcs12=true
            else
                bashio::log.error "cert_utils: Failed to generate new certificate for hostname change"
                return 1
            fi
        fi
    else
        # PKCS12 file doesn't exist yet
        need_pkcs12=true
    fi

    # Update PKCS12 if needed or missing
    if [[ "${regenerate_pkcs12}" == "true" || "${need_pkcs12}" == "true" ]]; then
        bashio::log.info "cert_utils: Generating PKCS12 certificate for Technitium DNS Server"
        if generate_pkcs12; then
            bashio::log.info "cert_utils: PKCS12 certificate generated successfully"
        else
            bashio::log.error "cert_utils: Failed to generate PKCS12 certificate"
            return 1
        fi
    else
        # Validate existing PKCS12 file
        if ! check_pkcs12; then
            bashio::log.info "cert_utils: Regenerating PKCS12 due to validation failure"
            if generate_pkcs12; then
                bashio::log.info "cert_utils: PKCS12 certificate regenerated successfully"
            else
                bashio::log.error "cert_utils: Failed to regenerate PKCS12 certificate"
                return 1
            fi
        fi
    fi

    bashio::log.debug "cert_utils: Certificate check complete - all certificates are valid"
    return 0
}

# -----------------------------------------------------------------------------
# Documentation References
# -----------------------------------------------------------------------------
# OpenSSL Certificate Commands: https://www.openssl.org/docs/man1.1.1/man1/
# Self-Signed Certificate: https://www.openssl.org/docs/man1.1.1/man1/req.html
# PKCS12 Format: https://www.openssl.org/docs/man1.1.1/man1/pkcs12.html
# Home Assistant SSL: https://www.home-assistant.io/docs/configuration/securing/
# Technitium Docs: https://blog.technitium.com/2020/07/how-to-host-your-own-dns-over-https-and.html
