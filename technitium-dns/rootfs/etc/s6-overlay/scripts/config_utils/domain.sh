#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Domain and Hostname Management Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Domain Name Resolution
# -----------------------------------------------------------------------------
# Determine the domain name to use for the DNS server
config_get_domain() {
	local default_hostname="homeassistant.local"
	local system_hostname
	local config_hostname
	local hostname

	bashio::log.debug "config_utils: Getting hostname..."

	# Priority 1: Use configured hostname if available
	if bashio::config.exists 'hostname' && bashio::config.has_value 'hostname'; then
		config_hostname="$(bashio::config 'hostname')"
		hostname="${config_hostname}"
		bashio::log.debug "config_utils: Using configured hostname: ${hostname}"

	# Priority 2: Use system hostname if available
	elif system_hostname=$(bashio::info.hostname 2>/dev/null) &&
		[[ -n ${system_hostname} && ${system_hostname} != "null" ]]; then
		hostname="${system_hostname}"
		bashio::log.debug "config_utils: Using system hostname: ${hostname}"

	# Priority 3: Fall back to default hostname
	else
		hostname="${default_hostname}"
		bashio::log.debug "config_utils: No valid hostname found, using default: ${hostname}"
	fi

	# Ensure hostname is an FQDN (contains at least one dot)
	if [[ ${hostname} != *.* ]]; then
		hostname="${hostname}.local"
		bashio::log.debug "config_utils: Adding .local suffix: ${hostname}"
	fi

	echo "${hostname}"
}
