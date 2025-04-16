#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Helper utilities for Technitium DNS Server
# ==============================================================================

if [[ "${DEBUG:-false}" == "true" ]]; then
    bashio::log.level 'debug'
fi

print_system_information() {
    dotnet_version=$(/usr/share/dotnet/dotnet --version || echo "unknown")
    bashio::log.debug "Config Utils: Dotnet runtime version: ${dotnet_version}"
    bashio::log.debug "Config Utils: System Information:"
    bashio::log.debug "Config Utils: $(bashio::info | jq . || true)"
    bashio::log.debug "Config Utils: System Enviroment Variabels:"
    bashio::log.debug "Config Utils: $(printenv || true)"
}

get_domain() {
    local default_hostname="homeassistant.local"
    local system_hostname
    local config_hostname
    local hostname

    bashio::log.debug "Config Utils: Getting hostname..."

    # Priority 1: Use configured hostname if available
    if bashio::config.exists 'hostname' && bashio::config.has_value 'hostname'; then
        config_hostname="$(bashio::config 'hostname')"
        hostname="${config_hostname}"
        bashio::log.debug "Config Utils: Using configured hostname: ${hostname}"

    # Priority 2: Use system hostname if available
    elif system_hostname="$(bashio::info.hostname 2>/dev/null)" &&
        [[ -n "${system_hostname}" && "${system_hostname}" != "null" ]]; then
        hostname="${system_hostname}"
        bashio::log.debug "Config Utils: Using system hostname: ${hostname}"

    # Priority 3: Fall back to default hostname
    else
        hostname="${default_hostname}"
        bashio::log.debug "Config Utils: No valid hostname found, using default: ${hostname}"
    fi

    # Ensure hostname is an FQDN (contains at least one dot)
    if [[ "${hostname}" != *.* ]]; then
        hostname="${hostname}.local"
        bashio::log.debug "Config Utils: Adding .local suffix: ${hostname}"
    fi

    echo "${hostname}"
}

get_cert_paths() {
    # Validate certificate file
    if bashio::config.exists 'certfile' && bashio::config.has_value 'certfile'; then
        CERT_FILE="$(bashio::config 'certfile')"
        if [[ ! -f "${CERT_FILE}" || ! -r "${CERT_FILE}" ]]; then
            bashio::log.debug "Config Utils: Configured certificate file not found or not readable: ${CERT_FILE}"
            CERT_FILE=""
        else
            bashio::log.debug "Config Utils: Using configured certificate file: ${CERT_FILE}"
        fi
    else
        bashio::log.debug "Config Utils: No certificate file configured"
        CERT_FILE=""
    fi

    # Try the Home Assistant SSL directory if primary cert file not available
    if [[ -z "${CERT_FILE}" && -f "/ssl/fullchain.pem" && -r "/ssl/fullchain.pem" ]]; then
        CERT_FILE="/ssl/fullchain.pem"
        bashio::log.debug "Config Utils: Using Home Assistant SSL certificate: ${CERT_FILE}"
    fi

    # Fall back to default SSL directory if needed
    if [[ -z "${CERT_FILE}" ]]; then
        CERT_FILE="/config/ssl/fullchain.pem"
        bashio::log.debug "Config Utils: Using default certificate location: ${CERT_FILE}"
    fi

    # Validate key file
    if bashio::config.exists 'keyfile' && bashio::config.has_value 'keyfile'; then
        KEY_FILE="$(bashio::config 'keyfile')"
        if [[ ! -f "${KEY_FILE}" || ! -r "${KEY_FILE}" ]]; then
            bashio::log.debug "Config Utils: Configured key file not found or not readable: ${KEY_FILE}"
            KEY_FILE=""
        else
            bashio::log.debug "Config Utils: Using configured key file: ${KEY_FILE}"
        fi
    else
        bashio::log.debug "Config Utils: No key file configured"
        KEY_FILE=""
    fi

    # Try the Home Assistant SSL directory if primary key file not available
    if [[ -z "${KEY_FILE}" && -f "/ssl/privkey.pem" && -r "/ssl/privkey.pem" ]]; then
        KEY_FILE="/ssl/privkey.pem"
        bashio::log.debug "Config Utils: Using Home Assistant SSL key: ${KEY_FILE}"
    fi

    # Fall back to default SSL directory if needed
    if [[ -z "${KEY_FILE}" ]]; then
        KEY_FILE="/config/ssl/privkey.pem"
        bashio::log.debug "Config Utils: Using default key location: ${KEY_FILE}"
    fi

    echo "${CERT_FILE}|${KEY_FILE}"
}

# -----------------------------------------------------------------------------
# DNS Forwarder Configuration
# -----------------------------------------------------------------------------
# Map selected forwarder name to DNS server and protocol configuration
get_forwarder_config() {
    local servers=""
    local protocol=""
    local forwarder
    forwarder="$(bashio::config 'forwarders' 'Cloudflare (DNS-over-HTTPS)')"

    # Map selected forwarder to appropriate server configuration
    case "${forwarder}" in
    # Standard UDP forwarders
    "Cloudflare (DNS-over-UDP)")
        servers="[\"1.1.1.1\",\"1.0.0.1\"]"
        protocol="Udp"
        ;;
    "Cloudflare (DNS-over-UDP IPv6)")
        servers="[\"[2606:4700:4700::1111] ([2606:4700:4700::1111])\",\"[2606:4700:4700::1001] ([2606:4700:4700::1001])\"]"
        protocol="Udp"
        ;;

    # TCP forwarders
    "Cloudflare (DNS-over-TCP)")
        servers="[\"1.1.1.1\",\"1.0.0.1\"]"
        protocol="Tcp"
        ;;
    "Cloudflare (DNS-over-TCP IPv6)")
        servers="[\"[2606:4700:4700::1111]\",\"[2606:4700:4700::1001]\"]"
        protocol="Tcp"
        ;;

    # TLS forwarders
    "Cloudflare (DNS-over-TLS)")
        servers="[\"cloudflare-dns.com (1.1.1.1:853)\",\"cloudflare-dns.com (1.0.0.1:853)\"]"
        protocol="Tls"
        ;;
    "Cloudflare (DNS-over-TLS IPv6)")
        servers="[\"cloudflare-dns.com ([2606:4700:4700::1111]:853)\",\"cloudflare-dns.com ([2606:4700:4700::1001]:853)\"]"
        protocol="Tls"
        ;;

    # HTTPS forwarders
    "Cloudflare (DNS-over-HTTPS)")
        servers="[\"https://cloudflare-dns.com/dns-query (1.1.1.1)\",\"https://cloudflare-dns.com/dns-query (1.0.0.1)\"]"
        protocol="Https"
        ;;
    "Cloudflare (DNS-over-HTTPS IPv6)")
        servers="[\"https://cloudflare-dns.com/dns-query ([2606:4700:4700::1111])\",\"https://cloudflare-dns.com/dns-query ([2606:4700:4700::1001])\"]"
        protocol="Https"
        ;;

    # Oblivious DNS-over-HTTPS (privacy-enhanced)
    "Cloudflare (Oblivious DNS-over-HTTPS)")
        servers="[\"https://odoh.cloudflare-dns.com/dns-query (1.1.1.1)\",\"https://odoh.cloudflare-dns.com/dns-query (1.0.0.1)\"]"
        protocol="Https"
        ;;
    "Cloudflare (Oblivious DNS-over-HTTPS IPv6)")
        servers="[\"https://odoh.cloudflare-dns.com/dns-query ([2606:4700:4700::1111])\",\"https://odoh.cloudflare-dns.com/dns-query ([2606:4700:4700::1001])\"]"
        protocol="Https"
        ;;

    # QUIC forwarders (HTTP/3)
    "Cloudflare (DNS-over-QUIC)")
        servers="[\"h3://cloudflare-dns.com (1.1.1.1)\",\"h3://cloudflare-dns.com (1.0.0.1)\"]"
        protocol="Quic"
        ;;
    "Cloudflare (DNS-over-QUIC IPv6)")
        servers="[\"h3://cloudflare-dns.com ([2606:4700:4700::1111])\",\"h3://cloudflare-dns.com ([2606:4700:4700::1001])\"]"
        protocol="Quic"
        ;;

    # TOR network forwarder (anonymized)
    "Cloudflare (DNS-over-TOR!)")
        servers="[\"dns4torpnlfs2ifuz2s2yf3fc7rdmsbhm6rw75euj35pac6ap25zgqad.onion\"]"
        protocol="Tcp"
        ;;

    # Default fallback
    *)
        bashio::log.warning "Config Utils: Unknown forwarder type '${forwarder}', defaulting to Cloudflare DNS over UDP"
        servers="[\"1.1.1.1\",\"1.0.0.1\"]"
        protocol="Udp"
        ;;
    esac

    echo "${servers}|${protocol}"
}
