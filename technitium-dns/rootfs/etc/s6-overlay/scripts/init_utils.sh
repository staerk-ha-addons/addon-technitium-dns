#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091

# Enable strict error handling
set -o nounset -o errexit -o pipefail

bashido::log.info "ENV Utils: Initializing Technitium DNS environment variables..."

# -----------------------------------------------------------------------------
# Module Dependencies
# -----------------------------------------------------------------------------
# Load utility modules
# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/env_utils.sh
source /etc/s6-overlay/scripts/utils/env_utils.sh
# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/cert_utils.sh
source /etc/s6-overlay/scripts/utils/cert_utils.sh
# shellcheck source=rootfs/etc/s6-overlay/scripts/utils/config_utils.sh
source /etc/s6-overlay/scripts/utils/config_utils.sh

# -----------------------------------------------------------------------------
# SSL Configuration
# -----------------------------------------------------------------------------

# Configure SSL based on flowchart logic
# Arguments:
#   $1 - Selected hostname
# Returns:
#   0 if SSL is configured, 1 if SSL is disabled
# shellcheck disable=SC2120
function configure_ssl() {
    local selected_hostname="${1}"
    local pkcs12_path=""
    local pkcs12_password=""
    local pem_cert_path=""
    local pem_key_path=""
    local need_self_signed=false
    local cert_hostname=""

    # Check if SSL is enabled
    bashio::log.info "Enable ssl $(bashio::config 'enable_ssl')"
    if ! bashio::config.true 'enable_ssl'; then
        bashio::log.info "DNS-Init: SSL disabled, skipping certificate configuration"
        return 1
    fi

    bashio::log.info "DNS-Init: SSL enabled, configuring certificates"

    # Get selected hostname
    if [[ -z "${selected_hostname}" ]]; then
        selected_hostname=$(select_hostname)
    fi
    bashio::log.info "DNS-Init: Selected hostname: ${selected_hostname}"

    # Get PKCS12 path
    pkcs12_path=$(handle_pkcs12_path)

    # Get PKCS12 password if specified
    if bashio::config.exists 'pkcs12_password' && bashio::config.has_value 'pkcs12_password'; then
        pkcs12_password=$(bashio::config 'pkcs12_password')
        bashio::log.info "DNS-Init: Using custom PKCS12 password"
    else
        pkcs12_password="TechnitiumDNSServer!SSL"
        bashio::log.info "DNS-Init: Using default PKCS12 password"
    fi

    # Check if PKCS12 file exists and is valid
    if validate_pkcs12 "${pkcs12_path}" "${pkcs12_password}"; then
        bashio::log.info "DNS-Init: Using existing PKCS12 certificate"
    else
        bashio::log.info "DNS-Init: PKCS12 certificate not found or invalid, checking for PEM certificate"

        # Handle PEM certificate paths
        handle_pem_paths pem_cert_path pem_key_path

        # Check if PEM files exist and are valid
        if validate_pem "${pem_cert_path}" "${pem_key_path}"; then
            bashio::log.info "DNS-Init: Valid PEM certificate found, converting to PKCS12"
            convert_pem_to_pkcs12 "${pem_cert_path}" "${pem_key_path}" "${pkcs12_path}" "${pkcs12_password}"
        else
            bashio::log.info "DNS-Init: No valid certificates found, will generate self-signed certificate"
            need_self_signed=true
        fi
    fi

    # Certificate Hostname Verification
    if ! "${need_self_signed}" && [[ -f "${pem_cert_path}" ]]; then
        cert_hostname=$(get_cert_hostname "${pem_cert_path}")

        if [[ "${cert_hostname}" == "${selected_hostname}" ]]; then
            bashio::log.info "DNS-Init: Certificate hostname matches selected hostname"
        else
            bashio::log.warning "DNS-Init: Certificate hostname (${cert_hostname}) doesn't match selected hostname (${selected_hostname})"

            # Check if certificate is self-signed
            if is_cert_self_signed "${pem_cert_path}"; then
                bashio::log.info "DNS-Init: Self-signed certificate with non-matching hostname, will generate new one"
                need_self_signed=true
            else
                bashio::log.warning "DNS-Init: Using certificate hostname (${cert_hostname}) instead of selected hostname"
                selected_hostname="${cert_hostname}"
            fi
        fi
    fi

    # Generate self-signed certificate if needed
    if "${need_self_signed}"; then
        bashio::log.info "DNS-Init: Generating self-signed certificate for ${selected_hostname}"
        generate_self_signed_cert "${selected_hostname}" "${pem_cert_path}" "${pem_key_path}"
        convert_pem_to_pkcs12 "${pem_cert_path}" "${pem_key_path}" "${pkcs12_path}" "${pkcs12_password}"
    fi

    # Set environment variables for SSL configuration
    write_env "DNS_ENABLE_SSL" "true"
    write_env "DNS_PKCS12_PATH" "${pkcs12_path}"
    write_env "DNS_PKCS12_PASSWORD" "${pkcs12_password}"
    write_env "DNS_HOSTNAME" "${selected_hostname}"

    return 0
}

# -----------------------------------------------------------------------------
# Forwarder Configuration
# -----------------------------------------------------------------------------
# Configure DNS dns_forwarders based on user selection in config.yaml
# No arguments
# Returns:
#   0 on success
function initialize_configuration() {
    local forwarder_config
    local servers
    local protocol
    local log_queries
    local enable_ssl
    local enable_dns_over_tls
    local enable_dns_over_https
    local enable_dns_over_https3
    local enable_dns_over_quic
    local ssl_result

    enable_ssl=$(bashio::config.true 'enable_ssl')
    enable_dns_over_tls=$(bashio::config.true 'enable_dns_over_tls')
    enable_dns_over_https=$(bashio::config.true 'enable_dns_over_https')
    enable_dns_over_https3=$(bashio::config.true 'enable_dns_over_https3')
    enable_dns_over_quic=$(bashio::config.true 'enable_dns_over_quic')
    log_queries=$(bashio::config.true 'log_queries')

    if bashio::config.true 'enable_ssl'; then
        ssl_result=$(configure_ssl)
        if [[ "${ssl_result}" -eq 0 ]]; then
            bashio::log.info "DNS-Init: SSL configured successfully"
            bashio::log.info "DNS-Init: SSL enabled: ${enable_ssl}"

        else
            bashio::log.warning "DNS-Init: SSL configuration failed, disabling SSL"
            enable_ssl=false
            bashio::log.info "DNS-Init: SSL disabled"
        fi
    else
        bashio::log.info "DNS-Init: SSL disabled"
    fi
    write_env "DNS_ENABLE_SSL" "${enable_ssl}"

    if bashio::config.false 'enable_ssl' && bashio::config.true 'enable_dns_over_tls'; then
        bashio::log.warning "DNS-Init: DNS-over-TLS requires SSL to be enabled"
        bashio::log.warning "DNS-Init: Disabling DNS-over-TLS"
        enable_dns_over_tls=false
    else
        bashio::log.info "DNS-Init: DNS-over-TLS enabled"
    fi

    if bashio::config.false 'enable_ssl' && bashio::config.true 'enable_dns_over_https'; then
        bashio::log.warning "DNS-Init: DNS-over-HTTPS requires SSL to be enabled"
        bashio::log.warning "DNS-Init: Disabling DNS-over-HTTPS"
        enable_dns_over_https=false
    else
        bashio::log.info "DNS-Init: DNS-over-HTTPS enabled"
    fi

    if bashio::config.false 'enable_ssl' && bashio::config.true 'enable_dns_over_https3'; then
        bashio::log.warning "DNS-Init: DNS-over-HTTPS3 requires SSL to be enabled"
        bashio::log.warning "DNS-Init: Disabling DNS-over-HTTPS3"
        enable_dns_over_https3=false
    else
        bashio::log.info "DNS-Init: DNS-over-HTTPS3 enabled"
    fi

    if bashio::config.false 'enable_ssl' && bashio::config.true 'enable_dns_over_quic'; then
        bashio::log.warning "DNS-Init: DNS-over-QUIC requires SSL to be enabled"
        bashio::log.warning "DNS-Init: Disabling DNS-over-QUIC"
        enable_dns_over_quic=false
    else
        bashio::log.info "DNS-Init: DNS-over-QUIC enabled"
    fi

    write_env "DNS_ENABLE_DNS_OVER_TLS" "${enable_dns_over_tls}"
    write_env "DNS_ENABLE_DNS_OVER_HTTPS" "${enable_dns_over_https}"
    write_env "DNS_ENABLE_DNS_OVER_HTTPS3" "${enable_dns_over_https3}"
    write_env "DNS_ENABLE_DNS_OVER_QUIC" "${enable_dns_over_quic}"


    write_env "DNS_LOG_QUERIES" "${log_queries}"
    bashio::log.info "DNS-Init: Log queries: ${log_queries}"


    bashio::log.info "DNS-Init: Configuring DNS dns_forwarders"

    # Get the forwarder configuration using the utility function
    forwarder_config=$(config_get_dns_forwarders)

    # Parse the returned string format "servers|protocol"
    servers=$(echo "${forwarder_config}" | cut -d'|' -f1)
    protocol=$(echo "${forwarder_config}" | cut -d'|' -f2)

    # Store the forwarder configuration in environment variables
    write_env "DNS_FORWARDER_SERVERS" "${servers}"
    write_env "DNS_FORWARDER_PROTOCOL" "${protocol}"


    bashio::log.info "DNS-Init: Forwarders servers: ${servers}"
    bashio::log.info "DNS-Init: Forwarders protocol: ${protocol}"
    return 0
}

