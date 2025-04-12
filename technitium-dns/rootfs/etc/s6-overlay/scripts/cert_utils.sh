#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Shared certificate utilities for Technitium DNS Server add-on
# ==============================================================================

CERTFILE="$(bashio::config 'certfile' '/ssl/fullchain.pem')"
KEYFILE="$(bashio::config 'keyfile' '/ssl/privkey.pem')"
PKCS12FILE="$(bashio::config 'pkcs12file' '/config/ssl/technitium.pfx')"

PASSWORD="$(bashio::config 'ssl_pfx_password')"
if [ -z "${PASSWORD}" ]; then
    bashio::log.warning "No SSL PFX password set, using the default password"
    PASSWORD="TechnitiumDNS!SSL"
fi

generate_self_signed_cert() {
    bashio::log.warning "Generating self-signed certificate as a fallback..."
    local selfsigned_cert="/config/ssl/selfsigned.pem"
    local selfsigned_key="/config/ssl/selfsigned.key"
    local hostname
    hostname="$(bashio::info.hostname)"

    if openssl req -x509 -newkey rsa:2048 -keyout "${selfsigned_key}" -out "${selfsigned_cert}" -days 365 -nodes \
        -subj "/CN=${hostname}"; then
        bashio::log.info "Successfully generated self-signed certificate"
        CERTFILE="${selfsigned_cert}"
        KEYFILE="${selfsigned_key}"
    else
        bashio::log.error "Failed to generate self-signed certificate"
        return 1
    fi
}

generate_cert() {
    bashio::log.info "Generating new PKCS #12 certificate..."
    if openssl pkcs12 -export \
        -out "${PKCS12FILE}" \
        -inkey "${KEYFILE}" \
        -in "${CERTFILE}" \
        -passout "pass:${PASSWORD}"; then
        bashio::log.info "Successfully generated PKCS #12 certificate at ${PKCS12FILE}"
    else
        bashio::log.error "Failed to generate PKCS #12 certificate"
        return 1
    fi
}

check_and_generate() {
    if ! bashio::fs.file_exists "${CERTFILE}" || ! bashio::fs.file_exists "${KEYFILE}"; then
        bashio::log.warning "Certificate files are missing — generating self-signed certificate"
        generate_self_signed_cert || return 1
    fi

    if bashio::fs.file_exists "${PKCS12FILE}"; then
        local EXPIRY
        EXPIRY="$(openssl pkcs12 -in "${PKCS12FILE}" -nokeys -passin "pass:${PASSWORD}" 2>/dev/null \
            | openssl x509 -noout -enddate \
            | cut -d= -f2)"

        if [ -n "${EXPIRY}" ]; then
            bashio::log.info "Existing PKCS #12 certificate expires on: ${EXPIRY}"

            if openssl x509 -checkend 0 -noout -in <(openssl pkcs12 -in "${PKCS12FILE}" -nokeys -passin "pass:${PASSWORD}" 2>/dev/null | openssl x509); then
                bashio::log.info "Existing PKCS #12 certificate is still valid — skipping generation"
                return
            fi
        fi
    fi

    generate_cert || return 1
}
