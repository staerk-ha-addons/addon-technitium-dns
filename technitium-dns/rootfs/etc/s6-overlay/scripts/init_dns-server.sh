#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154
# ==============================================================================
# Initializing Technitium DNS Server
# ==============================================================================

bashio::log.level 'debug'

# Wait for DNS server to fully initialize
sleep 5

bashio::log.debug "================================================="
bashio::log.debug "  Initializing Technitium DNS Server"
bashio::log.debug "================================================="

# -----------------------------------------------------------------------------
# Manual Configuration Check
# -----------------------------------------------------------------------------
if bashio::config.true 'manualConfig'; then
    bashio::log.debug "Manual configuration mode enabled - skipping automatic configuration"
    exit 0
fi

# -----------------------------------------------------------------------------
# Source Dependencies
# -----------------------------------------------------------------------------
# Try to source utils but don't fail if they're missing
if ! source "/etc/s6-overlay/scripts/api_utils.sh" 2>/dev/null; then
    bashio::log.error "Failed to source API utilities - continuing with limited functionality"
fi

if ! source "/etc/s6-overlay/scripts/cert_utils.sh" 2>/dev/null; then
    bashio::log.error "Failed to source certificate utilities - continuing with limited functionality"
fi

# -----------------------------------------------------------------------------
# Try to Configure DNS Server but don't fail on errors
# -----------------------------------------------------------------------------
bashio::log.debug "Attempting to configure DNS server..."

# Only run these if the functions exist
if type handle_cert_update >/dev/null 2>&1; then
    # Perform initial certificate setup but don't exit on failure
    handle_cert_update || bashio::log.error "Certificate update failed"
fi

if type make_api_call >/dev/null 2>&1; then
    # Apply configuration via API
    bashio::log.debug "Applying DNS server configuration..."
    make_api_call "settings/set" "POST" "{
        \"dnsServerDomain\": \"${ADDON_HOSTNAME}\",
        \"loggingType\": \"FileAndConsole\",
        \"logQueries\": ${ADDON_LOG_QUERIES},
        \"useLocalTime\": true,
        \"maxLogFileDays\": 7,
        \"maxStatFileDays\": 30,
        \"enableDnsOverTls\": ${ADDON_DNS_OVER_TLS},
        \"enableDnsOverHttps\": ${ADDON_DNS_OVER_HTTPS},
        \"enableDnsOverHttp3\": ${ADDON_DNS_OVER_HTTPS3},
        \"enableDnsOverQuic\": ${ADDON_DNS_OVER_QUIC},
        \"dnsTlsCertificatePath\": \"${ADDON_PKCS12_FILE}\",
        \"dnsTlsCertificatePassword\": \"${ADDON_PKCS12_PASSWORD}\",
        \"webServiceEnableTls\": true,
        \"webServiceEnableHttp3\": true,
        \"webServiceTlsCertificatePath\": \"${ADDON_PKCS12_FILE}\",
        \"webServiceTlsCertificatePassword\": \"${ADDON_PKCS12_PASSWORD}\",
        \"forwarders\": ${ADDON_FORWARDER_SERVERS},
        \"forwarderProtocol\": \"${ADDON_FORWARDER_PROTOCOL}\"
    }" || bashio::log.error "Failed to update DNS settings"

    # Install query logging app
    bashio::log.debug "Installing/updating query logs app..."
    manage_dns_app "Query Logs (Sqlite)" || bashio::log.error "Failed to install Query Logs app"
fi

# Always exit successfully
bashio::log.info "DNS server initialization completed"
exit 0
