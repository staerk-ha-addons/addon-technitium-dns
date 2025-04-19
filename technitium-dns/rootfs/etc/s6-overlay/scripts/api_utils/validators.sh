#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Input validation functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Input Validation Functions
# -----------------------------------------------------------------------------
# Validate JSON response from API
api_validate_response() {
	local response="${1}"
	if [[ -z ${response} ]]; then
		bashio::log.debug "api_utils: Empty response received"
		return 1
	fi

	if ! echo "${response}" | jq . >/dev/null 2>&1; then
		bashio::log.debug "api_utils: Invalid JSON response"
		return 1
	fi
	return 0
}

# Check that required parameters are provided for API calls
api_check_required_params() {
	local endpoint="${1}"
	local method="${2}"

	if [[ -z ${endpoint} ]]; then
		bashio::log.debug "api_utils: Missing API endpoint"
		return 1
	fi

	if [[ ! ${method} =~ ^(GET|POST)$ ]]; then
		bashio::log.debug "api_utils: Invalid HTTP method: ${method}"
		return 1
	fi

	return 0
}

# Compare version strings, returning 1 if version1 > version2,
# -1 if version1 < version2, and 0 if they're equal
# Usage: api_app_version_compare "1.2.3" "1.2.4"
api_app_version_compare() {
	local version1="${1//[^0-9.]/}"
	local version2="${2//[^0-9.]/}"

	# Ensure we have at least one digit
	[[ -z ${version1} ]] && version1="0"
	[[ -z ${version2} ]] && version2="0"

	# Compare version components
	local IFS=.
	# shellcheck disable=SC2206
	local ver1=(${version1})
	# shellcheck disable=SC2206
	local ver2=(${version2})

	# Fill empty fields with zeros
	for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
		ver1[i]=0
	done
	for ((i = ${#ver2[@]}; i < ${#ver1[@]}; i++)); do
		ver2[i]=0
	done

	# Compare version components
	local i
	for ((i = 0; i < ${#ver1[@]}; i++)); do
		# Convert string to integer by removing non-digit characters
		local v1="${ver1[i]//[^0-9]/}"
		local v2="${ver2[i]//[^0-9]/}"

		# Default to 0 if empty
		[[ -z ${v1} ]] && v1=0
		[[ -z ${v2} ]] && v2=0

		# Now compare as integers
		if ((v1 > v2)); then
			echo 1 # version1 > version2
			return
		elif ((v1 < v2)); then
			echo -1 # version1 < version2
			return
		fi
	done

	echo 0 # version1 == version2
}
