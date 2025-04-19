#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# DNS Forwarder Configuration Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# DNS Forwarder Configuration
# -----------------------------------------------------------------------------
# Map selected forwarder name to DNS server and protocol configuration
config_get_forwarders() {
	local servers=""
	local protocol=""
	local forwarder
	forwarder="$(bashio::config 'forwarders' 'Cloudflare (DNS-over-HTTPS)')"

	# Map selected forwarder to appropriate server configuration
	case "${forwarder}" in
	# Standard UDP forwarders
	"Cloudflare (DNS-over-UDP)")
		servers='["1.1.1.1","1.0.0.1"]'
		protocol="Udp"
		;;
	"Cloudflare (DNS-over-UDP IPv6)")
		servers='["[2606:4700:4700::1111] ([2606:4700:4700::1111])","[2606:4700:4700::1001] ([2606:4700:4700::1001])"]'
		protocol="Udp"
		;;

	# TCP forwarders
	"Cloudflare (DNS-over-TCP)")
		servers='["1.1.1.1","1.0.0.1"]'
		protocol="Tcp"
		;;
	"Cloudflare (DNS-over-TCP IPv6)")
		servers='["[2606:4700:4700::1111]","[2606:4700:4700::1001]"]'
		protocol="Tcp"
		;;

	# TLS forwarders
	"Cloudflare (DNS-over-TLS)")
		servers='["cloudflare-dns.com (1.1.1.1:853)","cloudflare-dns.com (1.0.0.1:853)"]'
		protocol="Tls"
		;;
	"Cloudflare (DNS-over-TLS IPv6)")
		servers='["cloudflare-dns.com ([2606:4700:4700::1111]:853)","cloudflare-dns.com ([2606:4700:4700::1001]:853)"]'
		protocol="Tls"
		;;

	# HTTPS forwarders
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

	# QUIC forwarders (HTTP/3)
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
