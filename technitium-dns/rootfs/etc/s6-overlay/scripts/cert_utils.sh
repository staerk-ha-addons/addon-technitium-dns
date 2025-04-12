#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Shared certificate utilities for Technitium DNS Server add-on
# ==============================================================================

CERTFILE=$(bashio::config 'certfile' '/ssl/fullchain.pem')
KEYFILE=$(bashio::config 'keyfile' '/ssl/privkey.pem')
PKCS12FILE=$(bashio::config 'pkcs12file' '/config/ssl/technitium.pfx')

PASSWORD=$(bashio::config 'ssl_pfx_password')
if [ -z "$PASSWORD" ]; then
    bashio::log.warning "No SSL PFX password set, using default password"
    PASSWORD="TechnitiumDNS!SSL"
fi

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
        bashio::log.warning "Certificate files missing — skipping generation"
        return
    fi

    if bashio::fs.file_exists "$PKCS12FILE"; then
        EXPIRY=$(openssl pkcs12 -in "$PKCS12FILE" -nokeys -passin "pass:${PASSWORD}" 2>/dev/null \
            | openssl x509 -noout -enddate \
            | cut -d= -f2)

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
