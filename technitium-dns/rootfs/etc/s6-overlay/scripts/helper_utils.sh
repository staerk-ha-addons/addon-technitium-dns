#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Helper utilities for Technitium DNS Server
# ==============================================================================

print_system_information() {
    dotnet_version=$(/usr/share/dotnet/dotnet --version || echo "unknown")
    bashio::log.debug "Dotnet runtime version: ${dotnet_version}"
    bashio::log.debug "System Information:"
    bashio::log.debug "$(bashio::info | jq . || true)"
    bashio::log.debug "System Enviroment Variabels:"
    bashio::log.debug "$(printenv || true)"
}

get_hostname() {
    local default_hostname="homeassistant.local"
    local system_hostname
    local config_hostname
    local hostname

    bashio::log.debug "Getting hostname..."

    # Priority 1: Use configured hostname if available
    if bashio::config.exists 'hostname' && bashio::config.has_value 'hostname'; then
        config_hostname="$(bashio::config 'hostname')"
        hostname="${config_hostname}"
        bashio::log.debug "Using configured hostname: ${hostname}"

    # Priority 2: Use system hostname if available
    elif system_hostname="$(bashio::info.hostname 2>/dev/null)" &&
        [[ -n "${system_hostname}" && "${system_hostname}" != "null" ]]; then
        hostname="${system_hostname}"
        bashio::log.debug "Using system hostname: ${hostname}"

    # Priority 3: Fall back to default hostname
    else
        hostname="${default_hostname}"
        bashio::log.debug "No valid hostname found, using default: ${hostname}"
    fi

    # Ensure hostname is an FQDN (contains at least one dot)
    if [[ "${hostname}" != *.* ]]; then
        hostname="${hostname}.local"
        bashio::log.debug "Adding .local suffix: ${hostname}"
    fi

    echo "${hostname}"
}

# -----------------------------------------------------------------------------
# DNS Forwarder Configuration
# -----------------------------------------------------------------------------
# Function to map forwarder name to DNS server and protocol
get_forwarder_config() {
    local forwarder="$1"
    local dns_servers=""
    local protocol=""

    # Map selected forwarder to appropriate server configuration
    case "${forwarder}" in
    # Standard UDP forwarders
    "Cloudflare (DNS-over-UDP)")
        dns_servers="[\"1.1.1.1\",\"1.0.0.1\"]"
        protocol="Udp"
        ;;
    "Cloudflare (DNS-over-UDP IPv6)")
        dns_servers="[\"[2606:4700:4700::1111] ([2606:4700:4700::1111])\",\"[2606:4700:4700::1001] ([2606:4700:4700::1001])\"]"
        protocol="Udp"
        ;;

    # TCP forwarders
    "Cloudflare (DNS-over-TCP)")
        dns_servers="[\"1.1.1.1\",\"1.0.0.1\"]"
        protocol="Tcp"
        ;;
    "Cloudflare (DNS-over-TCP IPv6)")
        dns_servers="[\"[2606:4700:4700::1111]\",\"[2606:4700:4700::1001]\"]"
        protocol="Tcp"
        ;;

    # TLS forwarders
    "Cloudflare (DNS-over-TLS)")
        dns_servers="[\"cloudflare-dns.com (1.1.1.1:853)\",\"cloudflare-dns.com (1.0.0.1:853)\"]"
        protocol="Tls"
        ;;
    "Cloudflare (DNS-over-TLS IPv6)")
        dns_servers="[\"cloudflare-dns.com ([2606:4700:4700::1111]:853)\",\"cloudflare-dns.com ([2606:4700:4700::1001]:853)\"]"
        protocol="Tls"
        ;;

    # HTTPS forwarders
    "Cloudflare (DNS-over-HTTPS)")
        dns_servers="[\"https://cloudflare-dns.com/dns-query (1.1.1.1)\",\"https://cloudflare-dns.com/dns-query (1.0.0.1)\"]"
        protocol="Https"
        ;;
    "Cloudflare (DNS-over-HTTPS IPv6)")
        dns_servers="[\"https://cloudflare-dns.com/dns-query ([2606:4700:4700::1111])\",\"https://cloudflare-dns.com/dns-query ([2606:4700:4700::1001])\"]"
        protocol="Https"
        ;;

    # Oblivious DNS-over-HTTPS (privacy-enhanced)
    "Cloudflare (Oblivious DNS-over-HTTPS)")
        dns_servers="[\"https://odoh.cloudflare-dns.com/dns-query (1.1.1.1)\",\"https://odoh.cloudflare-dns.com/dns-query (1.0.0.1)\"]"
        protocol="Https"
        ;;
    "Cloudflare (Oblivious DNS-over-HTTPS IPv6)")
        dns_servers="[\"https://odoh.cloudflare-dns.com/dns-query ([2606:4700:4700::1111])\",\"https://odoh.cloudflare-dns.com/dns-query ([2606:4700:4700::1001])\"]"
        protocol="Https"
        ;;

    # QUIC forwarders (HTTP/3)
    "Cloudflare (DNS-over-QUIC)")
        dns_servers="[\"h3://cloudflare-dns.com (1.1.1.1)\",\"h3://cloudflare-dns.com (1.0.0.1)\"]"
        protocol="Quic"
        ;;
    "Cloudflare (DNS-over-QUIC IPv6)")
        dns_servers="[\"h3://cloudflare-dns.com ([2606:4700:4700::1111])\",\"h3://cloudflare-dns.com ([2606:4700:4700::1001])\"]"
        protocol="Quic"
        ;;

    # TOR network forwarder (anonymized)
    "Cloudflare (DNS-over-TOR!)")
        dns_servers="[\"dns4torpnlfs2ifuz2s2yf3fc7rdmsbhm6rw75euj35pac6ap25zgqad.onion\"]"
        protocol="Tcp"
        ;;

    # Default fallback
    *)
        bashio::log.debug "Unknown forwarder type, defaulting to Cloudflare DNS over UDP"
        dns_servers="[\"1.1.1.1\",\"1.0.0.1\"]"
        protocol="Udp"
        ;;
    esac

    echo "${dns_servers}|${protocol}"
}
