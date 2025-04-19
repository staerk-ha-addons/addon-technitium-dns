#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=all
# ==============================================================================
# System Information Utility Functions
#
# Provides detailed information about the system environment, hardware,
# and runtime configuration for diagnostic and monitoring purposes.
# ==============================================================================
set -o nounset -o errexit -o pipefail

temp_file=$(mktemp)

# -----------------------------------------------------------------------------
# System Information Collection
# -----------------------------------------------------------------------------
# Print comprehensive system information for diagnostic purposes
# This function collects and displays system details in a structured format
# Usage: system_print_system_information
system_print_system_information() {
	# Create a temporary file for capturing output

	echo "=== System Information ===" >"${temp_file}"
	echo "Generated: $(date)" >>"${temp_file}"
	echo "" >>"${temp_file}"

	# Collect hardware information
	echo "--- Hardware Information ---" >>"${temp_file}"

	# CPU details
	if [[ -f /proc/cpuinfo ]]; then
		local cpu_model
		local cpu_cores
		local cpu_freq

		cpu_model=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d ":" -f2 | xargs)
		cpu_cores=$(grep -c "processor" /proc/cpuinfo)
		cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -n1 | cut -d ":" -f2 | xargs)

		echo "CPU:     ${cpu_model}" >>"${temp_file}"
		echo "Cores:   ${cpu_cores}" >>"${temp_file}"
		echo "Clock:   ${cpu_freq} MHz" >>"${temp_file}"
	else
		echo "CPU:     Information not available" >>"${temp_file}"
	fi

	# Memory information
	if [[ -f /proc/meminfo ]]; then
		local mem_total
		local mem_free
		local mem_available

		mem_total=$(grep "MemTotal" /proc/meminfo | awk '{printf "%.1f GB", $2/1024/1024}')
		mem_free=$(grep "MemFree" /proc/meminfo | awk '{printf "%.1f GB", $2/1024/1024}')
		mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{printf "%.1f GB", $2/1024/1024}')

		echo "Memory:  ${mem_total} total, ${mem_free} free, ${mem_available} available" >>"${temp_file}"
	else
		echo "Memory:  Information not available" >>"${temp_file}"
	fi

	# Disk space
	echo "Disk:" >>"${temp_file}"
	df -h | grep -v "tmpfs" | grep -v "udev" | grep -v "overlay" | while read -r line; do
		echo "        ${line}" >>"${temp_file}"
	done

	echo "" >>"${temp_file}"

	# System information
	echo "--- System Information ---" >>"${temp_file}"

	# Kernel and OS
	local kernel_version
	local os_name

	kernel_version=$(uname -r)
	echo "Kernel:  ${kernel_version}" >>"${temp_file}"

	if [[ -f /etc/os-release ]]; then
		os_name=$(grep "PRETTY_NAME" /etc/os-release | cut -d "=" -f2 | tr -d '"')
		echo "OS:      ${os_name}" >>"${temp_file}"
	else
		echo "OS:      Information not available" >>"${temp_file}"
	fi

	# Uptime
	if [[ -f /proc/uptime ]]; then
		local uptime_seconds
		local uptime_readable

		uptime_seconds=$(cut -d " " -f1 /proc/uptime)
		uptime_readable=$(awk -v up="${uptime_seconds}" 'BEGIN {
            days = int(up/86400); 
            hours = int((up - days*86400)/3600); 
            mins = int((up - days*86400 - hours*3600)/60);
            printf "%d days, %d hours, %d minutes", days, hours, mins
        }')

		echo "Uptime:  ${uptime_readable}" >>"${temp_file}"
	else
		echo "Uptime:  Information not available" >>"${temp_file}"
	fi

	# Add additional Home Assistant info
	echo "" >>"${temp_file}"
	echo "--- Add-on Information ---" >>"${temp_file}"

	# Capture bashio::info output
	{
		bashio::info | jq . || echo "Failed to retrieve bashio info"
	} >>"${temp_file}" 2>&1

	# Container information
	echo "" >>"${temp_file}"
	echo "--- Network Information ---" >>"${temp_file}"
	# Networking
	local ip_address
	ip_address=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
	echo "IP Address:     ${ip_address}" >>"${temp_file}"
	echo "Hostname:       $(hostname)" >>"${temp_file}"

	# Add environment variables section
	echo "" >>"${temp_file}"
	echo "--- Environment Variables (filtered) ---" >>"${temp_file}"

	# Capture environment variables using printenv
	# Filter out sensitive information that might be in environment variables
	{
		printenv | grep -v -i "password\|secret\|key\|token\|credential" | sort
	} >>"${temp_file}" 2>&1

	# Output the collected information
	cat "${temp_file}"

	# Clean up
	rm -f "${temp_file}"
}

# -----------------------------------------------------------------------------
# Resource Monitoring
# -----------------------------------------------------------------------------
# Show current system resources usage in a compact format
# Usage: system_show_resource_usage
system_show_resource_usage() {
	echo "=== System Resource Usage ==="

	# CPU usage
	local cpu_usage

	if command -v top &>/dev/null; then
		# Get CPU usage percentage using top (non-interactive)
		cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}')
		echo "CPU Usage:    ${cpu_usage}"
	else
		echo "CPU Usage:    Not available"
	fi

	# Memory usage
	if [[ -f /proc/meminfo ]]; then
		local mem_total
		local mem_available
		local mem_used_percent

		# Get memory values in KB
		mem_total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
		mem_available=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')

		# Calculate used memory percentage
		mem_used_percent=$(awk -v t="${mem_total}" -v a="${mem_available}" 'BEGIN {printf "%.1f%%", (t-a)*100/t}')

		# Convert to human-readable format
		mem_total=$(awk -v t="${mem_total}" 'BEGIN {printf "%.1f GB", t/1024/1024}')
		mem_available=$(awk -v a="${mem_available}" 'BEGIN {printf "%.1f GB", a/1024/1024}')

		echo "Memory:       ${mem_used_percent} (${mem_total} total, ${mem_available} available)"
	else
		echo "Memory:       Not available"
	fi

	# Disk usage
	echo "Disk Usage:"
	df -h | grep -E "/$|/data" | awk '{print "   " $6 ": " $5 " used (" $3 "/" $2 ")"}'

	# DNS server process status
	echo ""
	echo "DNS Server Process:"

	if pgrep -f "DnsServerApp.dll" >/dev/null; then
		local dns_pid
		local dns_cpu
		local dns_memory
		local dns_time

		dns_pid=$(pgrep -f "DnsServerApp.dll" | head -n 1)

		# Get process statistics if PID is available
		if [[ -n ${dns_pid} ]]; then
			# CPU usage might need top or ps, using ps here
			dns_cpu=$(ps -p "${dns_pid}" -o %cpu= | xargs)
			dns_memory=$(ps -p "${dns_pid}" -o rss= | awk '{printf "%.1f MB", $1/1024}')
			dns_time=$(ps -p "${dns_pid}" -o etime= | xargs)

			echo "   Status:      Running (PID: ${dns_pid})"
			echo "   CPU:         ${dns_cpu}%"
			echo "   Memory:      ${dns_memory}"
			echo "   Running for: ${dns_time}"
		else
			echo "   Status:      Running"
		fi
	else
		echo "   Status:      Not running"
	fi
}

cleanup() {
	# Clean up temporary files and resources
	rm -f "${temp_file}"
}
trap cleanup EXIT
