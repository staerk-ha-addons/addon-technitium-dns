#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Certificate Generation Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Certificate Generation Functions
# -----------------------------------------------------------------------------
# Create a new self-signed certificate with current hostname as subject
cert_generate_self_signed() {
	bashio::log.info "cert_utils: Generating self-signed certificate for hostname: ${ADDON_DOMAIN}"

	local gen_result
	cert_openssl_command openssl req -x509 \
		-newkey rsa:4096 \
		-keyout "${ADDON_KEY_FILE}" \
		-out "${ADDON_CERT_FILE}" \
		-days 365 \
		-nodes \
		-subj "/CN=${ADDON_DOMAIN}" \
		-addext "subjectAltName=DNS:${ADDON_DOMAIN}" >/dev/null 2>&1
	gen_result=$?

	if [[ ${gen_result} -eq 0 ]]; then
		# Set appropriate permissions to protect private key
		if ! chmod 600 "${ADDON_KEY_FILE}"; then
			bashio::log.warning "cert_utils: Failed to set permissions on key file"
		fi
		if ! chmod 644 "${ADDON_CERT_FILE}"; then
			bashio::log.warning "cert_utils: Failed to set permissions on certificate file"
		fi
		bashio::log.debug "cert_utils: Set secure permissions on certificate files (600 for key, 644 for cert)"
		bashio::log.debug "cert_utils: Self-signed certificate generated successfully"
		return 0
	else
		bashio::log.error "cert_utils: Failed to generate self-signed certificate"
		return 1
	fi
}
