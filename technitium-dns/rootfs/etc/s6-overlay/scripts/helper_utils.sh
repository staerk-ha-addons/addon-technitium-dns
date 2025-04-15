#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Helper utilities for Technitium DNS Server
# ==============================================================================

print_system_information() {
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

    print_system_information
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
