#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# DNS Forwarder Configuration Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Hostname Selection Functions
# -----------------------------------------------------------------------------

# Select the hostname based on priority logic from flowchart
# No arguments
# Returns the selected hostname
function select_hostname() {
    local selected_hostname=""

    bashio::log.info "DNS-Init: Selecting hostname"

    # Check config hostname (highest priority)
    if bashio::config.exists 'hostname' && bashio::config.has_value 'hostname'; then
        selected_hostname=$(bashio::config 'hostname')
        bashio::log.info "DNS-Init: Using configured hostname: ${selected_hostname}"

    # Check home assistant hostname
    elif ha_hostname=$(bashio::info.hostname 2>/dev/null) && \
         [[ -n "${ha_hostname}" ]] && \
         [[ "${ha_hostname}" != "null" ]]; then
        selected_hostname="${ha_hostname}"
        bashio::log.info "DNS-Init: Using home assistant hostname: ${selected_hostname}"

    # Check addon hostname
    elif [[ -n "${HOSTNAME}" ]]; then
        selected_hostname="${HOSTNAME}"
        bashio::log.info "DNS-Init: Using addon hostname: ${selected_hostname}"

    # Use default hostname (lowest priority)
    else
        selected_hostname="homeassistant.local"
        bashio::log.info "DNS-Init: Using default hostname: ${selected_hostname}"
    fi

    # Check if hostname is FQDN (contains at least one dot)
    if [[ "${selected_hostname}" != *.* ]]; then
        bashio::log.info "DNS-Init: Hostname is not FQDN, appending .local domain"
        selected_hostname="${selected_hostname}.local"
        bashio::log.info "DNS-Init: Using FQDN hostname: ${selected_hostname}"
    fi

    echo "${selected_hostname}"
}

# -----------------------------------------------------------------------------
# DNS Forwarder Configuration
# -----------------------------------------------------------------------------
# Map selected forwarder name to DNS server and protocol configuration
config_get_dns_forwarders() {
	local servers=""
	local protocol=""
	local forwarder
	forwarder="$(bashio::config 'dns_forwarders' 'Cloudflare (DNS-over-HTTPS)')"

	# Map selected forwarder to appropriate server configuration
	case "${forwarder}" in
	# Standard UDP dns_forwarders
	"Cloudflare (DNS-over-UDP)")
		servers='["1.1.1.1","1.0.0.1"]'
		protocol="Udp"
		;;
	"Cloudflare (DNS-over-UDP IPv6)")
		servers='["[2606:4700:4700::1111] ([2606:4700:4700::1111])","[2606:4700:4700::1001] ([2606:4700:4700::1001])"]'
		protocol="Udp"
		;;

	# TCP dns_forwarders
	"Cloudflare (DNS-over-TCP)")
		servers='["1.1.1.1","1.0.0.1"]'
		protocol="Tcp"
		;;
	"Cloudflare (DNS-over-TCP IPv6)")
		servers='["[2606:4700:4700::1111]","[2606:4700:4700::1001]"]'
		protocol="Tcp"
		;;

	# TLS dns_forwarders
	"Cloudflare (DNS-over-TLS)")
		servers='["cloudflare-dns.com (1.1.1.1:853)","cloudflare-dns.com (1.0.0.1:853)"]'
		protocol="Tls"
		;;
	"Cloudflare (DNS-over-TLS IPv6)")
		servers='["cloudflare-dns.com ([2606:4700:4700::1111]:853)","cloudflare-dns.com ([2606:4700:4700::1001]:853)"]'
		protocol="Tls"
		;;

	# HTTPS dns_forwarders
	"Cloudflare (DNS-over-HTTPS)")
		servers='["https://cloudflare-dns.com/dns-query (1.1.1.1)","https://cloudflare-dns.com/dns-query (1.0.0.1)"]'
		protocol="Https"
		;;
	"Cloudflare (DNS-over-HTTPS IPv6)")
		servers='["https://cloudflare-dns.com/dns-query ([2606:4700:4700::1111])","https://cloudflare-dns.com/dns-query ([2606:4700:4700::1001])"]'
		protocol="Https"
		;;

	# Oblivious DNS-over-HTTPS (privacy-enhanced)
	"Cloudflare (Oblivious DNS-over-HTTPS)")
		servers='["https://odoh.cloudflare-dns.com/dns-query (1.1.1.1)","https://odoh.cloudflare-dns.com/dns-query (1.0.0.1)"]'
		protocol="Https"
		;;
	"Cloudflare (Oblivious DNS-over-HTTPS IPv6)")
		servers='["https://odoh.cloudflare-dns.com/dns-query ([2606:4700:4700::1111])","https://odoh.cloudflare-dns.com/dns-query ([2606:4700:4700::1001])"]'
		protocol="Https"
		;;

	# QUIC dns_forwarders (HTTP/3)
	"Cloudflare (DNS-over-QUIC)")
		servers='["h3://cloudflare-dns.com (1.1.1.1)","h3://cloudflare-dns.com (1.0.0.1)"]'
		protocol="Quic"
		;;
	"Cloudflare (DNS-over-QUIC IPv6)")
		servers='["h3://cloudflare-dns.com ([2606:4700:4700::1111])","h3://cloudflare-dns.com ([2606:4700:4700::1001])"]'
		protocol="Quic"
		;;

	# TOR network forwarder (anonymized)
	"Cloudflare (DNS-over-TOR!)")
		servers='["dns4torpnlfs2ifuz2s2yf3fc7rdmsbhm6rw75euj35pac6ap25zgqad.onion"]'
		protocol="Tcp"
		;;

	# Default fallback
	*)
		bashio::log.warning "config_utils: Unknown forwarder type '${forwarder}', defaulting to Cloudflare DNS over UDP"
		servers='["1.1.1.1","1.0.0.1"]'
		protocol="Udp"
		;;
	esac

	echo "${servers}|${protocol}"
}
