
if ! command -v openssl >/dev/null 2>&1; then
    bashio::log.error "openssl binary not found!"
    exit 1
fi

# Default values
DEFAULT_PASSWORD="TechnitiumDNS!SSL"
DEFAULT_PKCS12="/config/ssl/technitium.pfx"
DEFAULT_CERT="/config/ssl/fullchain.pem"
DEFAULT_KEY="/config/ssl/privkey.key"
DEFAULT_HOSTNAME="homeassistant.local"
SSL_DIR="/config/ssl"

# 0. Set hostname
HOST_SYSTEM_HOSTNAME=$(bashio::info.hostname)
if [ -z "$HOST_SYSTEM_HOSTNAME" ]; then
    HOSTNAME="$DEFAULT_HOSTNAME"
else
    HOSTNAME="$HOST_SYSTEM_HOSTNAME"
fi

# 1. Get password with default
PASSWORD=$(bashio::config 'password' "$DEFAULT_PASSWORD")
if [ "$PASSWORD" = "$DEFAULT_PASSWORD" ]; then
    bashio::log.warning "Using default password for SSL certificate - consider changing this for security"
fi

# 2. Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# 3. Get certificate paths with defaults
PKCS12_FILE=$(bashio::config 'pkcs12file' "$DEFAULT_PKCS12")
CERT_FILE=$(bashio::config 'certfile' "$DEFAULT_CERT")
KEY_FILE=$(bashio::config 'keyfile' "$DEFAULT_KEY")

# Check PKCS12 validity if it exists
check_pkcs12() {
    if [ -f "$PKCS12_FILE" ]; then
        # First check if the PKCS12 file is valid
        if ! openssl pkcs12 -in "$PKCS12_FILE" -noout -passin pass:"$PASSWORD" 2>/dev/null; then
            bashio::log.warning "Invalid PKCS12 file"
            return 1
        fi

        # Get expiration date and format it
        EXPIRY_DATE=$(openssl pkcs12 -in "$PKCS12_FILE" -nokeys -passin pass:"$PASSWORD" 2>/dev/null | \
                      openssl x509 -noout -enddate | cut -d'=' -f2)

        # Extract certificate from PKCS12 and check expiration
        if openssl pkcs12 -in "$PKCS12_FILE" -nokeys -passin pass:"$PASSWORD" 2>/dev/null | \
           openssl x509 -noout -checkend 0 2>/dev/null; then
            bashio::log.info "Valid non-expired PKCS12 file found (expires: ${EXPIRY_DATE}), skipping certificate generation"
            return 0
        else
            bashio::log.warning "PKCS12 certificate is expired (expired: ${EXPIRY_DATE})"
            return 1
        fi
    fi
    bashio::log.warning "No PKCS12 file found"
    return 1
}

# Check if cert and key paths are valid
check_cert_paths() {
    # Check if cert file exists and is readable
    if [ ! -f "$CERT_FILE" ] || [ ! -r "$CERT_FILE" ]; then
        bashio::log.warning "Certificate file not found or not readable, using default: $DEFAULT_CERT"
        CERT_FILE="$DEFAULT_CERT"
    else
        bashio::log.info "Using certificate file: $CERT_FILE"
    fi

    # Check if key file exists and is readable
    if [ ! -f "$KEY_FILE" ] || [ ! -r "$KEY_FILE" ]; then
        bashio::log.warning "Key file not found or not readable, using default: $DEFAULT_KEY"
        KEY_FILE="$DEFAULT_KEY"
    else
        bashio::log.info "Using key file: $KEY_FILE"
    fi
}

# Generate self-signed certificate
generate_self_signed() {
    bashio::log.info "Generating self-signed certificate..."
    openssl req -x509 \
        -newkey rsa:4096 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days 365 \
        -nodes \
        -subj "/CN=$HOSTNAME"
}

# Generate PKCS12 from cert and key
generate_pkcs12() {
    bashio::log.info "Generating PKCS12 file..."
    openssl pkcs12 -export \
        -out "$PKCS12_FILE" \
        -inkey "$KEY_FILE" \
        -in "$CERT_FILE" \
        -password pass:"$PASSWORD"
}
