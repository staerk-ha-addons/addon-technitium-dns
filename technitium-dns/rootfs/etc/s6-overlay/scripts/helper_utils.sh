#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Helper utilities for Technitium DNS Server
# ==============================================================================

print_system_information(){
    bashio::log.debug "System Information:"
    bashio::log.debug "$(bashio::info | jq .)"
    bashio::log.debug "System Enviroment Variabels:"
    bashio::log.debug "$(printenv)"
}

get_hostname() {
    local system_hostname
    local default_hostname="homeassistant.local"
    local hostname

    system_hostname=$(bashio::info.hostname)

    # Check for empty, null or undefined hostname
    if [[ -z "$system_hostname" || "$system_hostname" == "null" || "$system_hostname" == "undefined" ]]; then
        hostname="$default_hostname"
        bashio::log.debug "Empty or invalid hostname, using default: ${hostname}"
    else
        hostname="$system_hostname"
    fi

    # Check if hostname is an FQDN (contains at least one dot)
    if [[ "$hostname" != *.* ]]; then
        hostname="${hostname}.local"
        bashio::log.debug "Hostname not an FQDN, using: ${hostname}"
    else
        bashio::log.debug "Using FQDN hostname: ${hostname}"
    fi

    echo "$hostname"
}
