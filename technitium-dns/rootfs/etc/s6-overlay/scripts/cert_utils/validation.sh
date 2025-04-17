#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Certificate Validation Functions
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Certificate Validation Functions
# -----------------------------------------------------------------------------
# Verify PKCS12 certificate exists and is valid (not expired)
cert_check_pkcs12() {
    local expiry_date

    # Check if the file exists
    if [[ ! -f "${ADDON_PKCS12_FILE}" ]]; then
        bashio::log.debug "cert_utils: No PKCS12 file found at ${ADDON_PKCS12_FILE}"
        return 1
    fi

    # Validate file can be opened with correct password and is proper PKCS12 format
    if ! cert_openssl_command openssl pkcs12 -in "${ADDON_PKCS12_FILE}" -noout -passin pass:"${ADDON_PKCS12_PASSWORD}" >/dev/null 2>&1; then
        bashio::log.warning "cert_utils: Invalid PKCS12 file format at ${ADDON_PKCS12_FILE}"
        return 1
    fi

    # Extract X.509 certificate from PKCS12 to check expiration
    local cert_data

    # Fix SC2312: Invoke function separately to avoid masking return value
    cert_data=$(cert_extract_cert_data)
    local extract_status=$?

    if [[ ${extract_status} -ne 0 ]]; then
        bashio::log.warning "cert_utils: Failed to extract certificate data from PKCS12 file"
        return 1
    fi

    # Process expiration date from certificate data
    if [[ -n "${cert_data}" ]]; then
        # Extract expiry date in human-readable format
        local expiry_output
        expiry_output=$(echo "${cert_data}" | cert_openssl_command openssl x509 -noout -enddate 2>/dev/null)
        expiry_date=$(echo "${expiry_output}" | cut -d'=' -f2)

        # Simplify date calculation and reduce subshells
        local days_remaining expiry_seconds current_seconds
        expiry_seconds=$(date -d "${expiry_date}" +%s)
        current_seconds=$(date +%s)
        days_remaining=$(((expiry_seconds - current_seconds) / 86400))
        bashio::log.debug "cert_utils: Certificate validity: ${days_remaining} days remaining"

        # Check if certificate is still valid (not expired)
        if ! echo "${cert_data}" | cert_openssl_command openssl x509 -noout -checkend 0 >/dev/null 2>&1; then
            # Certificate has expired
            bashio::log.warning "cert_utils: PKCS12 certificate has expired (expired: ${expiry_date}) - renewal required"
            return 1
        fi

        # Check if certificate will expire within 30 days (2592000 seconds)
        if ! echo "${cert_data}" | cert_openssl_command openssl x509 -noout -checkend 2592000 >/dev/null 2>&1; then
            bashio::log.warning "cert_utils: Certificate will expire within 30 days (on: ${expiry_date})"
        else
            bashio::log.debug "cert_utils: Certificate valid for more than 30 days"
        fi

        return 0
    else
        bashio::log.warning "cert_utils: Empty certificate data extracted from PKCS12 file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Certificate Hostname Validation
# -----------------------------------------------------------------------------
# Verify certificate contains the current hostname in CN or SAN fields
cert_check_hostname() {
    local cert_cn
    local cert_sans
    local hostname_match=false

    # Skip validation if PKCS12 file doesn't exist
    if [[ ! -f "${ADDON_PKCS12_FILE}" ]]; then
        bashio::log.debug "cert_utils: No PKCS12 file exists yet for hostname validation"
        return 1
    fi

    # Extract certificate data from PKCS12 for hostname comparison
    local cert_data

    # Fix SC2312: Invoke function separately to avoid masking return value
    cert_data=$(cert_extract_cert_data)
    local extract_status=$?

    if [[ ${extract_status} -ne 0 ]]; then
        bashio::log.warning "cert_utils: Cannot extract certificate data for hostname validation"
        return 1
    fi

    # Extract Subject Common Name (CN) from certificate for comparison
    local subject_output
    subject_output=$(echo "${cert_data}" | cert_openssl_command openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null)
    if [[ "${subject_output}" =~ CN=([^,]*) ]]; then
        cert_cn="${BASH_REMATCH[1]}"
    else
        cert_cn=""
    fi

    # Extract Subject Alternative Names (SANs) for additional hostname matches
    local sans_output
    sans_output=$(echo "${cert_data}" | cert_openssl_command openssl x509 -noout -ext subjectAltName 2>/dev/null)
    cert_sans=$(echo "${sans_output}" | grep -o "DNS:[^,]*" | sed 's/DNS://g')

    # Log certificate details for debugging
    bashio::log.debug "cert_utils: Certificate CN: ${cert_cn}"
    bashio::log.debug "cert_utils: Certificate SANs: ${cert_sans}"
    bashio::log.debug "cert_utils: Current hostname: ${ADDON_DOMAIN}"

    # Check if current hostname matches the certificate's Common Name
    if [[ "${cert_cn}" == "${ADDON_DOMAIN}" ]]; then
        bashio::log.debug "cert_utils: Certificate CN '${cert_cn}' matches configured domain '${ADDON_DOMAIN}'"
        hostname_match=true
    fi

    # Check if current hostname matches any of the Subject Alternative Names
    if [[ "${hostname_match}" == "false" ]] && [[ -n "${cert_sans}" ]]; then
        # Iterate through each SAN entry and check for hostname match
        # Each entry represents a single DNS name the certificate is valid for
        while read -r san; do
            if [[ "${san}" == "${ADDON_DOMAIN}" ]]; then
                bashio::log.debug "cert_utils: Hostname matches certificate SAN: ${san}"
                hostname_match=true
                break
            fi
        done < <(echo "${cert_sans}")
    fi

    # Return success if hostname matches certificate, otherwise failure
    if [[ "${hostname_match}" == "true" ]]; then
        bashio::log.debug "cert_utils: Certificate valid for current hostname: ${ADDON_DOMAIN}"
        return 0
    else
        bashio::log.warning "cert_utils: Certificate NOT valid for current hostname - regeneration required"
        return 1
    fi
}
