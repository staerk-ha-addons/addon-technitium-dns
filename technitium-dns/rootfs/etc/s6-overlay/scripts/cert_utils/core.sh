#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Core certificate management functionality
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Dependency Check
# -----------------------------------------------------------------------------
# Verify OpenSSL is available for certificate operations
if ! command -v openssl >/dev/null 2>&1; then
	bashio::log.error "cert_utils: OpenSSL binary not found! Certificate management requires OpenSSL."
	exit 1
fi

# -----------------------------------------------------------------------------
# Environment Variable Check
# -----------------------------------------------------------------------------
# Ensure all required environment variables are set before proceeding
required_env_vars=("ADDON_SSL_DIR" "ADDON_CERT_FILE" "ADDON_KEY_FILE" "ADDON_PKCS12_FILE" "ADDON_PKCS12_PASSWORD" "ADDON_DOMAIN")

for var in "${required_env_vars[@]}"; do
	if [[ -z ${!var} ]]; then
		bashio::log.error "cert_utils: Required environment variable ${var} is not set!"
		exit 1
	fi
done

bashio::log.trace "cert_utils: All required environment variables present"

# -----------------------------------------------------------------------------
# Main Certificate Management Function
# -----------------------------------------------------------------------------
# Orchestrates certificate validation, generation and updates
cert_update() {
	local last_checked_file="${ADDON_SSL_DIR}/.last_checked"
	local current_time max_check_interval
	current_time=$(date +%s)
	max_check_interval=86400 # Once per day

	# Skip redundant checks if certificates were validated recently
	if [[ -f ${last_checked_file} ]] && [[ -f ${ADDON_PKCS12_FILE} ]]; then
		local last_check_time
		if [[ -r ${last_checked_file} ]]; then
			last_check_time=$(<"${last_checked_file}")
		else
			last_check_time=0
		fi
		if ((current_time - last_check_time < max_check_interval)); then
			bashio::log.debug "cert_utils: Certificate recently validated, skipping check"
			return 0
		fi
	fi

	bashio::log.info "cert_utils: Checking certificate status..."

	# Track state changes to minimize unnecessary operations
	local recert_generate_pkcs12=false
	local need_pkcs12=false

	# Check if basic certificate files exist
	if [[ ! -f ${ADDON_CERT_FILE} || ! -f ${ADDON_KEY_FILE} ]]; then
		bashio::log.info "cert_utils: Certificate or key file missing - generating self-signed certificate"

		# Fix SC2312: Invoke command separately to avoid masking return value
		cert_generate_self_signed
		local self_signed_result=$?

		if [[ ${self_signed_result} -eq 0 ]]; then
			recert_generate_pkcs12=true
		else
			bashio::log.error "cert_utils: Failed to generate self-signed certificate"
			return 1
		fi
	fi

	# Verify certificate hostname matches current configuration
	if [[ -f ${ADDON_PKCS12_FILE} ]]; then
		# Fix SC2310/SC2312: Run commands separately to avoid masking return values
		cert_check_hostname
		local hostname_match_result=$?

		if [[ ${hostname_match_result} -ne 0 ]]; then
			bashio::log.info "cert_utils: Current hostname doesn't match certificate - regenerating"

			# Fix SC2312: Invoke command separately to avoid masking return value
			cert_generate_self_signed
			local regen_result=$?

			if [[ ${regen_result} -eq 0 ]]; then
				recert_generate_pkcs12=true
			else
				bashio::log.error "cert_utils: Failed to generate new certificate for hostname change"
				return 1
			fi
		fi
	else
		need_pkcs12=true
	fi

	# Update PKCS12 if needed or missing
	if [[ ${recert_generate_pkcs12} == "true" || ${need_pkcs12} == "true" ]]; then
		if [[ ${recert_generate_pkcs12} == "true" ]]; then
			bashio::log.info "cert_utils: Regenerating PKCS12 file due to certificate changes"
		else
			bashio::log.info "cert_utils: Creating new PKCS12 file from existing certificate"
		fi

		# Fix SC2312: Invoke command separately to avoid masking return value
		cert_generate_pkcs12
		local gen_pkcs12_result=$?

		if [[ ${gen_pkcs12_result} -eq 0 ]]; then
			bashio::log.info "cert_utils: PKCS12 certificate generated successfully"
		else
			bashio::log.error "cert_utils: Failed to generate PKCS12 certificate"
			return 1
		fi
	else
		# Fix SC2312: Invoke command separately to avoid masking return value
		cert_check_pkcs12
		local check_result=$?

		if [[ ${check_result} -ne 0 ]]; then
			bashio::log.info "cert_utils: Regenerating PKCS12 due to validation failure"

			# Fix SC2312: Invoke command separately to avoid masking return value
			cert_generate_pkcs12
			local regen_result=$?

			if [[ ${regen_result} -eq 0 ]]; then
				bashio::log.info "cert_utils: PKCS12 certificate regenerated successfully"
			else
				bashio::log.error "cert_utils: Failed to regenerate PKCS12 certificate"
				return 1
			fi
		fi
	fi

	# Update the last checked timestamp
	if ! echo "${current_time}" >"${last_checked_file}"; then
		bashio::log.warning "cert_utils: Failed to update certificate check timestamp"
	fi

	bashio::log.debug "cert_utils: Certificate check complete - all certificates are valid"
	return 0
}
