#!/command/with-contenv bashio
# shellcheck shell=bash
# -----------------------------------------------------------------------------
# Home Assistant Add-on: Technitium DNS
# Certificate handling utilities
# -----------------------------------------------------------------------------

# Enable strict mode
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Certificate Handling Functions
# -----------------------------------------------------------------------------

# Convert PEM format certificate/key to PKCS12 format
# Arguments:
#   $1 - Certificate file path
#   $2 - Key file path
#   $3 - Output PKCS12 file path
#   $4 - Optional PKCS12 password
function convert_pem_to_pkcs12() {
    local cert_file="${1}"
    local key_file="${2}"
    local output_file="${3}"
    local password="${4:-}"
    local openssl_exit_code

    bashio::log.info "DNS-Init: Converting PEM certificate to PKCS12 format"

    # Ensure the output directory exists
    mkdir -p "$(dirname "${output_file}")"

    if [[ -z "${password}" ]]; then
        # No password
        openssl_exit_code=$(openssl pkcs12 -export -out "${output_file}" -inkey "${key_file}" -in "${cert_file}" -passout pass:)
    else
        # With password
        openssl_exit_code=$(openssl pkcs12 -export -out "${output_file}" -inkey "${key_file}" -in "${cert_file}" -passout "pass:${password}")
    fi

    # Check the result of the conversion
    if [[ openssl_exit_code -ne 0 ]]; then
        bashio::log.error "DNS-Init: Failed to convert PEM certificate to PKCS12 format"
        bashio::exit.nok "Certificate conversion failed"
    fi

    bashio::log.info "DNS-Init: Successfully converted certificate to PKCS12 format"
    return 0
}

# Generate a self-signed certificate for the given hostname
# Arguments:
#   $1 - Hostname to use in certificate
#   $2 - Output certificate file path
#   $3 - Output key file path
function generate_self_signed_cert() {
    local hostname="${1}"
    local cert_file="${2}"
    local key_file="${3}"

    # Ensure the output directory exists
    mkdir -p "$(dirname "${cert_file}")"

    # Generate private key
    openssl genrsa -out "${key_file}" 2048

    # Generate self-signed certificate valid for 1 year
    openssl req -new -x509 -key "${key_file}" -out "${cert_file}" -days 365 \
        -subj "/CN=${hostname}" \
        -addext "subjectAltName = DNS:${hostname}"

    # Check if certificate generation was successful
    if [[ $? -ne 0 ]]; then
        bashio::log.error "DNS-Init: Failed to generate self-signed certificate"
        bashio::exit.nok "Certificate generation failed"
    fi

    bashio::log.info "DNS-Init: Successfully generated self-signed certificate"
    return 0
}

# Validate PKCS12 certificate file
# Arguments:
#   $1 - PKCS12 file path
#   $2 - Optional PKCS12 password
function validate_pkcs12() {
    local pkcs12_file="${1}"
    local password="${2:-}"

    bashio::log.debug "DNS-Init: Validating PKCS12 certificate at ${pkcs12_file}"

    # Check if file exists
    if [[ ! -f "${pkcs12_file}" ]]; then
        bashio::log.debug "DNS-Init: PKCS12 file does not exist"
        return 1
    fi

    # Validate PKCS12 file with appropriate password handling
    if [[ -z "${password}" ]]; then
        # No password
        if ! openssl pkcs12 -in "${pkcs12_file}" -noout -passin pass: &> /dev/null; then
            bashio::log.debug "DNS-Init: PKCS12 validation failed"
            return 1
        fi
    else
        # With password
        if ! openssl pkcs12 -in "${pkcs12_file}" -noout -passin "pass:${password}" &> /dev/null; then
            bashio::log.debug "DNS-Init: PKCS12 validation failed"
            return 1
        fi
    fi

    bashio::log.debug "DNS-Init: PKCS12 validation successful"
    return 0
}

# Validate PEM certificate and key files
# Arguments:
#   $1 - Certificate file path
#   $2 - Key file path
function validate_pem() {
    local cert_file="${1}"
    local key_file="${2}"

    bashio::log.debug "DNS-Init: Validating PEM certificate and key"

    # Check if files exist
    if [[ ! -f "${cert_file}" ]] || [[ ! -f "${key_file}" ]]; then
        bashio::log.debug "DNS-Init: Certificate or key file does not exist"
        return 1
    fi

    # Validate certificate format
    if ! openssl x509 -in "${cert_file}" -noout &> /dev/null; then
        bashio::log.debug "DNS-Init: Certificate validation failed"
        return 1
    fi

    # Validate key format
    if ! openssl rsa -in "${key_file}" -check -noout &> /dev/null; then
        bashio::log.debug "DNS-Init: Key validation failed"
        return 1
    fi

    # Extract and compare certificate and key moduli to verify they match
    local cert_modulus
    local key_modulus
    cert_modulus=$(openssl x509 -in "${cert_file}" -noout -modulus | sha256sum)
    key_modulus=$(openssl rsa -in "${key_file}" -noout -modulus | sha256sum)

    if [[ "${cert_modulus}" != "${key_modulus}" ]]; then
        bashio::log.debug "DNS-Init: Certificate and key do not match"
        return 1
    fi

    bashio::log.debug "DNS-Init: PEM validation successful"
    return 0
}

# Extract hostname from certificate
# Arguments:
#   $1 - Certificate file in PEM format
function get_cert_hostname() {
    local cert_file="${1}"
    local hostname

    # Extract the Common Name (CN) from the certificate subject
    hostname=$(openssl x509 -in "${cert_file}" -noout -subject | sed -n 's/.*CN=\([^\/]*\).*/\1/p')

    # If no CN found, try to get the first SAN DNS entry
    if [[ -z "${hostname}" ]]; then
        hostname=$(openssl x509 -in "${cert_file}" -noout -ext subjectAltName 2>/dev/null | grep -o 'DNS:[^,]*' | head -1 | cut -d':' -f2)
    fi

    echo "${hostname}"
}

# Check if certificate is self-signed
# Arguments:
#   $1 - Certificate file in PEM format
function is_cert_self_signed() {
    local cert_file="${1}"
    local issuer
    local subject

    # Compare MD5 hashes of issuer and subject - if they match, cert is self-signed
    issuer=$(openssl x509 -in "${cert_file}" -noout -issuer | md5sum)
    subject=$(openssl x509 -in "${cert_file}" -noout -subject | md5sum)

    if [[ "${issuer}" == "${subject}" ]]; then
        return 0  # True, is self-signed
    else
        return 1  # False, not self-signed
    fi
}

# Handle PKCS12 certificate path determination
# Returns the path to use
function handle_pkcs12_path() {
    local pkcs12_path=""

    # Check if custom PKCS12 path is configured
    if bashio::config.exists 'pkcs12_path' && bashio::config.has_value 'pkcs12_path'; then
        pkcs12_path=$(bashio::config 'pkcs12_path')
        bashio::log.info "DNS-Init: Using custom PKCS12 path: ${pkcs12_path}"
    else
        pkcs12_path="/config/cert/technitium.pfx"
        bashio::log.info "DNS-Init: Using default PKCS12 path: ${pkcs12_path}"
    fi

    echo "${pkcs12_path}"
}

# Handle PEM certificate paths determination
# Arguments:
#   $1 - Reference to variable that will store cert path
#   $2 - Reference to variable that will store key path
function handle_pem_paths() {
    local -n cert_path_ref="${1}"
    local -n key_path_ref="${2}"

    # Check if custom PEM paths are configured
    if bashio::config.exists 'pem_cert_path' && bashio::config.has_value 'pem_cert_path' \
       && bashio::config.exists 'pem_key_path' && bashio::config.has_value 'pem_key_path'; then
        cert_path_ref=$(bashio::config 'pem_cert_path')
        key_path_ref=$(bashio::config 'pem_key_path')
        bashio::log.info "DNS-Init: Using custom PEM paths: ${cert_path_ref} and ${key_path_ref}"

    # Check if Home Assistant SSL certificates exist
    elif [[ -f "/ssl/fullchain.pem" ]] && [[ -f "/ssl/privkey.pem" ]]; then
        cert_path_ref="/ssl/fullchain.pem"
        key_path_ref="/ssl/privkey.pem"
        bashio::log.info "DNS-Init: Using Home Assistant SSL certificates"

    # Use default paths as last resort
    else
        cert_path_ref="/config/cert/technitium.crt"
        key_path_ref="/config/cert/technitium.key"
        bashio::log.info "DNS-Init: Using default PEM paths: ${cert_path_ref} and ${key_path_ref}"
    fi
}
