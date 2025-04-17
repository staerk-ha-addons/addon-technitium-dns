#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC1091,SC2154
# ==============================================================================
# Technitium DNS Server Add-on: Utility Function Testing
#
# This script provides a mechanism to test individual utility functions from
# the command line. It serves as a development and troubleshooting tool that
# allows calling any function with arguments from the terminal for verification
# and debugging purposes.
# ==============================================================================
set -o nounset -o errexit -o pipefail

# -----------------------------------------------------------------------------
# Color Definitions
# -----------------------------------------------------------------------------
# Define terminal color codes for better readability
readonly ANSI_RED="\033[0;31m"
readonly ANSI_GREEN="\033[0;32m"
readonly ANSI_YELLOW="\033[0;33m"
readonly ANSI_BLUE="\033[0;34m"
readonly ANSI_MAGENTA="\033[0;35m"
readonly ANSI_CYAN="\033[0;36m"
readonly ANSI_WHITE="\033[0;37m"
readonly ANSI_BOLD="\033[1m"
readonly ANSI_RESET="\033[0m"

# -----------------------------------------------------------------------------
# Emoji Definitions
# -----------------------------------------------------------------------------
# Define commonly used emojis for terminal output
readonly EMOJI_SUCCESS="✅"
readonly EMOJI_ERROR="❌"
readonly EMOJI_WARNING="⚠️ "
readonly EMOJI_INFO="ℹ️ "
readonly EMOJI_DEBUG="🔍"
readonly EMOJI_EXEC="🚀"
readonly EMOJI_CONFIG="⚙️ "
readonly EMOJI_API="🌐"
readonly EMOJI_CERT="🔒"
readonly EMOJI_TIME="⏱️ "

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
# Display help information about this script
cli_show_help() {
    echo -e "${ANSI_BOLD}${ANSI_CYAN}${EMOJI_INFO} Utility Function Testing Helper${ANSI_RESET}"
    echo ""
    echo -e "${ANSI_BOLD}USAGE:${ANSI_RESET}"
    echo -e "  utils_cli.sh ${ANSI_YELLOW}<function_name>${ANSI_RESET} [arg1] [arg2] ..."
    echo -e "  utils_cli.sh ${ANSI_GREEN}--list${ANSI_RESET}           List all available functions"
    echo -e "  utils_cli.sh ${ANSI_GREEN}--list-all${ANSI_RESET}       List all available functions on the system"
    echo -e "  utils_cli.sh ${ANSI_GREEN}--help${ANSI_RESET}           Show this help message"
    echo ""
}

# Display all available utility functions
cli_list_functions() {
    echo -e "${ANSI_BOLD}${ANSI_CYAN}${EMOJI_INFO} Available utility functions:${ANSI_RESET}"
    echo ""

    # Extract and display callable functions from all utility modules
    # Format the output for better readability

    # API utilities
    echo -e "${ANSI_BOLD}${ANSI_GREEN}${EMOJI_API} == API Utilities == ${EMOJI_API}${ANSI_RESET}"

    # Get API utilities and apply formatting directly using echo -e
    declare -F | grep -v "^declare -f _" | awk '{print $3}' | grep -E "^(api_)" | sort | while read -r func; do
        echo -e "${ANSI_WHITE}${func}${ANSI_RESET}"
    done
    echo ""

    # Certificate utilities
    echo -e "${ANSI_BOLD}${ANSI_MAGENTA}${EMOJI_CERT} == Certificate Utilities == ${EMOJI_CERT}${ANSI_RESET}"

    # Get certificate utilities and apply formatting directly using echo -e
    declare -F | grep -v "^declare -f _" | awk '{print $3}' | grep -E "^(cert_)" | sort | while read -r func; do
        echo -e "${ANSI_WHITE}${func}${ANSI_RESET}"
    done
    echo ""

    # Configuration utilities
    echo -e "${ANSI_BOLD}${ANSI_CYAN}${EMOJI_CONFIG} == Configuration Utilities == ${EMOJI_CONFIG}${ANSI_RESET}"

    # Get configuration utilities and apply formatting directly using echo -e
    declare -F | grep -v "^declare -f _" | awk '{print $3}' | grep -E "^(config_)" | sort | while read -r func; do
        echo -e "${ANSI_WHITE}${func}${ANSI_RESET}"
    done
    echo ""

    # Find any uncategorized functions
    echo -e "${ANSI_BOLD}${ANSI_WHITE}${EMOJI_DEBUG} == Other Functions == ${EMOJI_DEBUG}${ANSI_RESET}"

    # Filter out already categorized functions and helper functions from this script
    declare -F | grep -v "^declare -f _" | awk '{print $3}' | grep -v -E "^(api_|cert_|config_|bashio|hass)" | sort | while read -r func; do
        echo -e "${ANSI_WHITE}${func}${ANSI_RESET}"
    done
    echo ""
}

# Display all available utility functions
cli_list_all_functions() {
    echo -e "${ANSI_BOLD}${ANSI_YELLOW}${EMOJI_INFO} Available functions on system:${ANSI_RESET}"
    echo ""

    # Find any uncategorized functions
    echo -e "${ANSI_BOLD}${ANSI_CYAN}${EMOJI_DEBUG} == All Functions == ${EMOJI_DEBUG}${ANSI_RESET}"

    # Filter out already categorized functions and helper functions from this script
    declare -F | grep -v "^declare -f _" | awk '{print $3}' | sort | while read -r func; do
        echo -e "${ANSI_WHITE}${func}${ANSI_RESET}"
    done
    echo ""
}

# -----------------------------------------------------------------------------
# Load All Utility Modules
# -----------------------------------------------------------------------------
# First source all utility modules to make their functions available
# shellcheck source=rootfs/etc/s6-overlay/scripts/all_utils.sh
source /etc/s6-overlay/scripts/all_utils.sh

# -----------------------------------------------------------------------------
# Command Processing
# -----------------------------------------------------------------------------
# Check for help or list commands first
if [[ $# -eq 1 && "${1}" == "--help" ]]; then
    cli_show_help
    exit 0
fi

if [[ $# -eq 1 && "${1}" == "--list" ]]; then
    cli_list_functions
    exit 0
fi

if [[ $# -eq 1 && "${1}" == "--list-all" ]]; then
    cli_list_all_functions
    exit 0
fi

# -----------------------------------------------------------------------------
# Parameter Validation
# -----------------------------------------------------------------------------
# Ensure a function name is provided as the first argument
if [[ $# -lt 1 ]]; then
    echo -e "${ANSI_RED}${EMOJI_ERROR} ERROR: No function name provided as the first argument${ANSI_RESET}" >&2
    echo "Usage: utils_cli.sh <function_name> [arg1] [arg2] ..." >&2
    echo -e "Use '${ANSI_GREEN}--help${ANSI_RESET}' for more information" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Function Resolution and Execution
# -----------------------------------------------------------------------------
# Extract the function name from the first argument
function_name="${1}"

# Check if the function exists and is callable
if declare -f "${function_name}" >/dev/null; then
    # Use bashio log for debug as it's typically hidden
    bashio::log.debug "Executing function '${function_name}' with ${#}-1 arguments"

    # Call the function with the remaining arguments
    # We're intentionally splitting the arguments here (SC2086 is acceptable)
    # shellcheck disable=SC2086

    # Print a status header for the function execution
    echo -e "${ANSI_BOLD}${ANSI_BLUE}${EMOJI_EXEC} Executing: ${function_name}${ANSI_RESET}"

    # Track execution time
    start_time=$(date +%s.%N)

    # Execute the function and capture both output and return value
    output=$("${function_name}" "${@:2}")
    result=$?

    # Calculate execution time
    end_time=$(date +%s.%N)
    duration=$(awk "BEGIN {printf \"%.3f\", ${end_time} - ${start_time}}")

    # Display output header if there is any result
    if [[ -n "${output}" ]]; then
        echo -e "${ANSI_BOLD}${ANSI_WHITE}-- Result Output --${ANSI_RESET}"
        echo "${output}"
        echo -e "${ANSI_BOLD}${ANSI_WHITE}-- End Output --${ANSI_RESET}"
    fi

    # Report function execution result with appropriate color
    if [[ "${result}" -eq 0 ]]; then
        echo -e "${ANSI_GREEN}${EMOJI_SUCCESS} SUCCESS: Function '${function_name}' executed successfully (return code: ${result})${ANSI_RESET}"
        echo -e "${ANSI_BOLD}${EMOJI_TIME} Execution time: ${duration} seconds${ANSI_RESET}"
    else
        echo -e "${ANSI_YELLOW}${EMOJI_WARNING} WARNING: Function '${function_name}' returned non-zero exit code: ${result}${ANSI_RESET}" >&2
        echo -e "${ANSI_BOLD}${EMOJI_TIME} Execution time: ${duration} seconds${ANSI_RESET}" >&2
    fi

    # Return the original function's exit code
    exit "${result}"
else
    # Function not found - provide helpful error with available functions
    cli_list_functions >&2
    echo "" >&2
    echo -e "${ANSI_RED}${EMOJI_ERROR} ERROR: Function '${function_name}' not found${ANSI_RESET}" >&2
    echo "" >&2
    echo -e "Use '${ANSI_GREEN}--help${ANSI_RESET}' for more information" >&2

    exit 1
fi
