#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# PKCS12 Format Conversion and Handling
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# PKCS12 Conversion Functions
# -----------------------------------------------------------------------------
# Convert standard X.509 certificate and private key to PKCS12 format
cert_generate_pkcs12() {
    bashio::log.info "cert_utils: Generating PKCS12 file from certificate and key..."

    # Verify source files exist before conversion
    if [[ ! -f "${ADDON_CERT_FILE}" ]]; then
        bashio::log.error "cert_utils: Certificate file doesn't exist: ${ADDON_CERT_FILE}"
        return 1
    fi

    if [[ ! -f "${ADDON_KEY_FILE}" ]]; then
        bashio::log.error "cert_utils: Key file doesn't exist: ${ADDON_KEY_FILE}"
        return 1
    fi

    local pkcs12_result
    cert_openssl_command openssl pkcs12 -export \
        -out "${ADDON_PKCS12_FILE}" \
        -inkey "${ADDON_KEY_FILE}" \
        -in "${ADDON_CERT_FILE}" \
        -password pass:"${ADDON_PKCS12_PASSWORD}" >/dev/null 2>&1
    pkcs12_result=$?

    if [[ ${pkcs12_result} -eq 0 ]]; then
        # Set restrictive permissions on the PKCS12 file (contains private key)
        if ! chmod 600 "${ADDON_PKCS12_FILE}"; then
            bashio::log.warning "cert_utils: Failed to set permissions on PKCS12 file"
        fi
        bashio::log.debug "cert_utils: PKCS12 file generated successfully: ${ADDON_PKCS12_FILE}"
        return 0
    else
        bashio::log.error "cert_utils: Failed to generate PKCS12 file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Documentation References
# -----------------------------------------------------------------------------
# OpenSSL Certificate Commands: https://www.openssl.org/docs/man1.1.1/man1/
# Self-Signed Certificate: https://www.openssl.org/docs/man1.1.1/man1/req.html
# PKCS12 Format: https://www.openssl.org/docs/man1.1.1/man1/pkcs12.html
# Home Assistant SSL: https://www.home-assistant.io/docs/configuration/securing/
# Technitium Docs: https://blog.technitium.com/2020/07/how-to-host-your-own-dns-over-https-and.html
