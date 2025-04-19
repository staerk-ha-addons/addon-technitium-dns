#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# System Information and Configuration Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# System Information Reporting
# -----------------------------------------------------------------------------
# Print detailed system information for debugging and diagnostics
config_print_system_information() {
	local dotnet_version

	# Fix SC2312: Execute command separately to avoid masking its return value
	dotnet_version=$(/usr/share/dotnet/dotnet --version 2>/dev/null || echo "unknown")

	bashio::log.debug "config_utils: Dotnet runtime version: ${dotnet_version}"

	# Run system info commands in a way that doesn't mask return values
	bashio::log.debug "config_utils: System Information:"

	# Fix SC2312: Store output separately to avoid masking exit status
	local system_info
	if system_info=$(bashio::info | jq . 2>/dev/null); then
		bashio::log.debug "config_utils: ${system_info}"
	else
		bashio::log.debug "config_utils: Could not retrieve system information"
	fi

	# Fix SC2312: Store output separately to avoid masking exit status
	bashio::log.debug "config_utils: System Environment Variables:"
	local env_vars
	if env_vars=$(printenv 2>/dev/null); then
		bashio::log.debug "config_utils: ${env_vars}"
	else
		bashio::log.debug "config_utils: Could not retrieve environment variables"
	fi
}
