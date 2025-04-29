#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# API token management functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Token Management
# -----------------------------------------------------------------------------
# Save API token to encrypted storage
api_save_token() {
	local token="${1}"

	if [[ -z ${token} ]]; then
		bashio::log.debug "api_utils: Cannot save empty token"
		return 1
	fi

	if api_acquire_lock; then
		api_encrypt_token "${token}" >"${DNS_API_TOKEN_FILE}"
		chmod 600 "${DNS_API_TOKEN_FILE}"
		local status=$?
		api_release_lock

		if [[ ${status} -eq 0 ]]; then
			bashio::log.debug "api_utils: API token encrypted and saved"
			return 0
		else
			bashio::log.warning "api_utils: Failed to save encrypted token"
			return 1
		fi
	fi

	bashio::log.warning "api_utils: Failed to acquire lock for saving token"
	return 1
}

# Load and decrypt the saved API token
api_load_token() {
	if [[ ! -f ${DNS_API_TOKEN_FILE} ]]; then
		bashio::log.debug "api_utils: No saved token file exists"
		return 1
	fi

	if ! api_acquire_lock; then
		bashio::log.warning "api_utils: Failed to acquire lock for loading token"
		return 1
	fi

	local encrypted_token
	local saved_token
	encrypted_token=$(cat "${DNS_API_TOKEN_FILE}")
	saved_token=$(api_decrypt_token "${encrypted_token}")
	api_release_lock

	if [[ -z ${saved_token} ]]; then
		bashio::log.warning "api_utils: Failed to decrypt token"

		# Clean up invalid token file
		if api_acquire_lock; then
			rm -f "${DNS_API_TOKEN_FILE}"
			api_release_lock
			bashio::log.debug "api_utils: Removed invalid token file"
		fi

		return 1
	fi

	echo "${saved_token}"
	bashio::log.debug "api_utils: Successfully loaded saved API token"
	return 0
}

# Get authentication token, creating one if needed
# shellcheck disable=SC2120
api_get_token() {
	local username="${1:-$(bashio::config 'username' 'admin')}"
	local password="${2:-$(bashio::config 'password' 'admin')}"
	local token
	local max_retries=3
	local retry=0
	local response

	# Try to load existing token first
	token=$(api_load_token)
	if [[ -n ${token} ]]; then
		bashio::log.debug "api_utils: Using saved token"
		echo "${token}"
		return 0
	fi

	bashio::log.info "api_utils: Creating new API token..."

	while ((retry < max_retries)); do
		# Create permanent token - preferred method
		bashio::log.debug "api_utils: Attempting token creation (attempt ${retry})"

		# Invoke API call separately to avoid masking return value (SC2312)
		response=$(api_direct "user/createToken?user=${username}&pass=${password}&tokenName=${DNS_API_TOKEN_NAME}")
		call_status=$?

		if [[ ${call_status} -eq 0 ]]; then
			# Use jq separately to avoid masking its return value (SC2312)
			token=$(jq -r '.token // empty' <<<"${response}")
			if [[ -n ${token} ]]; then
				bashio::log.info "api_utils: API token created successfully"
				api_save_token "${token}"
				echo "${token}"
				return 0
			else
				bashio::log.warning "api_utils: API token creation failed - empty token (attempt ${retry})"
			fi
		else
			bashio::log.warning "api_utils: API token creation call failed (attempt ${retry})"
		fi

		# Fallback to standard login if token creation fails
		bashio::log.info "api_utils: API token creation failed, trying standard login..."

		# Invoke API call separately to avoid masking return value (SC2312)
		response=$(api_direct "user/login?user=${username}&pass=${password}&includeInfo=true")
		call_status=$?

		if [[ ${call_status} -eq 0 ]]; then
			# Use jq separately to avoid masking its return value (SC2312)
			token=$(jq -r '.token // empty' <<<"${response}")
			if [[ -n ${token} ]]; then
				bashio::log.debug "api_utils: Authentication successful using standard login"
				echo "${token}"
				return 0
			fi
		fi

		((retry++))
		if ((retry < max_retries)); then
			bashio::log.warning "api_utils: Authentication attempt ${retry} failed, retrying in 2s..."
			sleep 2
		fi
	done

	bashio::log.error "api_utils: Authentication failed after ${max_retries} attempts"
	return 1
}
