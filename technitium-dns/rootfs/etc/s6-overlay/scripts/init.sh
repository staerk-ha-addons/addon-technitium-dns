#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091
# -----------------------------------------------------------------------------
# Home Assistant Add-on: Technitium DNS
# Initializes the DNS server with proper hostname and SSL configuration
# -----------------------------------------------------------------------------

# Enable strict mode
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Module Dependencies
# -----------------------------------------------------------------------------
# Load utility modules
# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/api_utils.sh
source /etc/s6-overlay/scripts/utils/api_utils.sh

# Configure final DNS server settings
# Arguments:
#   $1 - Selected hostname
function configure_dns_server() {

    bashio::log.info "DNS-Init: Setting up DNS server with hostname: ${DNS_HOSTNAME}"

    # Set DNS server settings using the API
    api_call "settings/set" "POST" "{
        \"dnsServerDomain\": \"${DNS_HOSTNAME}\",
        \"loggingType\": \"FileAndConsole\",
        \"logQueries\": ${DNS_LOG_QUERIES},
        \"useLocalTime\": true,
        \"maxLogFileDays\": 7,
        \"maxStatFileDays\": 30,
        \"enableDnsOverTls\": ${DNS_ENABLE_DNS_OVER_TLS},
        \"enableDnsOverHttps\": ${DNS_ENABLE_DNS_OVER_HTTPS},
        \"enableDnsOverHttp3\": ${DNS_ENABLE_DNS_OVER_HTTPS3},
        \"enableDnsOverQuic\": ${DNS_ENABLE_DNS_OVER_QUIC},
        \"dnsTlsCertificatePath\": \"${DNS_PKCS12_PATH}\",
        \"dnsTlsCertificatePassword\": \"${DNS_PKCS12_PASSWORD}\",
        \"webServiceEnableTls\": ${DNS_ENABLE_SSL},
        \"webServiceEnableHttp3\": ${DNS_ENABLE_SSL},
        \"webServiceUseSelfSignedTlsCertificate\": false,
        \"webServiceTlsCertificatePath\": \"${DNS_PKCS12_PATH}\",
        \"webServiceTlsCertificatePassword\": \"${DNS_PKCS12_PASSWORD}\",
        \"forwarders\": ${DNS_FORWARDER_SERVERS},
        \"forwarderProtocol\": \"${DNS_FORWARDER_PROTOCOL}\"
    }"

    bashio::log.info "DNS-Init: DNS server initialization completed"
}

# -----------------------------------------------------------------------------
# Main Execution Flow
# -----------------------------------------------------------------------------

# Primary initialization function that orchestrates the entire setup process
# No arguments
function init_dns_server() {

    bashio::log.info "DNS-Init: Starting DNS server initialization"

    # Step 1: Configure DNS server
    configure_dns_server

    bashio::log.info "DNS-Init: DNS server initialization completed successfully"

    # Return SSL configuration status for potential use by calling scripts
    return 0
}

# Execute initialization
init_dns_server
