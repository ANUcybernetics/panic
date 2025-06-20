#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly SSH_KEY_NAME="panic_rpi_ssh"
readonly SSH_KEY_PATH="${HOME}/.ssh/${SSH_KEY_NAME}"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [command]

SSH helper for accessing Pi running in QEMU.

Commands:
  connect         Connect to Pi via SSH (default)
  test            Test SSH connection
  copy-id         Copy SSH key to Pi (if needed)
  logs            Show systemd logs from Pi
  status          Show Pi system status
  reboot          Reboot the Pi
  shutdown        Shutdown the Pi

Examples:
  $0              # Connect to Pi
  $0 connect      # Connect to Pi
  $0 test         # Test if SSH is working
  $0 logs         # Show recent logs
  $0 status       # Show system status
EOF
}

# Function to test SSH connection
test_ssh() {
    printf "Testing SSH connection to Pi...\n"
    if ssh -i "${SSH_KEY_PATH}" -p 5555 -o ConnectTimeout=5 -o StrictHostKeyChecking=no panic@localhost "echo 'SSH connection successful'" 2>/dev/null; then
        printf "✅ SSH connection working\n"
        return 0
    else
        printf "❌ SSH connection failed\n"
        printf "Make sure QEMU is running with: ./run-qemu.sh\n"
        return 1
    fi
}

# Function to connect via SSH
connect_ssh() {
    if [[ ! -f "${SSH_KEY_PATH}" ]]; then
        printf "Error: SSH key not found at %s\n" "${SSH_KEY_PATH}" >&2
        printf "Run './workflow.sh prepare-base' first\n" >&2
        exit 1
    fi

    printf "Connecting to Pi via SSH...\n"
    printf "SSH key: %s\n" "${SSH_KEY_PATH}"
    printf "Command: ssh -i %s -p 5555 panic@localhost\n\n" "${SSH_KEY_PATH}"

    ssh -i "${SSH_KEY_PATH}" -p 5555 -o StrictHostKeyChecking=no panic@localhost
}

# Function to show logs
show_logs() {
    printf "Showing recent Pi logs...\n"
    ssh -i "${SSH_KEY_PATH}" -p 5555 -o StrictHostKeyChecking=no panic@localhost "sudo journalctl -n 50 --no-pager"
}

# Function to show status
show_status() {
    printf "Pi System Status:\n"
    ssh -i "${SSH_KEY_PATH}" -p 5555 -o StrictHostKeyChecking=no panic@localhost "
        echo '=== System Info ==='
        uname -a
        echo
        echo '=== Uptime ==='
        uptime
        echo
        echo '=== Memory Usage ==='
        free -h
        echo
        echo '=== Disk Usage ==='
        df -h /
        echo
        echo '=== Running Processes ==='
        ps aux | grep -E '(chromium|kiosk|lxde)' | grep -v grep || echo 'No kiosk processes found'
        echo
        echo '=== Network Status ==='
        ip addr show | grep -E '(inet|UP)' || echo 'Network info unavailable'
    "
}

# Function to reboot Pi
reboot_pi() {
    printf "Rebooting Pi...\n"
    ssh -i "${SSH_KEY_PATH}" -p 5555 -o StrictHostKeyChecking=no panic@localhost "sudo reboot" || true
    printf "Pi is rebooting. Wait a moment before reconnecting.\n"
}

# Function to shutdown Pi
shutdown_pi() {
    printf "Shutting down Pi...\n"
    ssh -i "${SSH_KEY_PATH}" -p 5555 -o StrictHostKeyChecking=no panic@localhost "sudo shutdown -h now" || true
    printf "Pi is shutting down. QEMU should exit automatically.\n"
}

# Function to copy SSH key (fallback)
copy_ssh_key() {
    printf "Copying SSH key to Pi...\n"
    if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
        printf "Error: SSH public key not found at %s.pub\n" "${SSH_KEY_PATH}" >&2
        exit 1
    fi

    # This requires password authentication to be enabled
    ssh-copy-id -i "${SSH_KEY_PATH}.pub" -p 5555 panic@localhost
    printf "SSH key copied. You should now be able to connect without password.\n"
}

# Parse command line arguments
COMMAND="${1:-connect}"

case "$COMMAND" in
    "connect"|"")
        connect_ssh
        ;;
    "test")
        test_ssh
        ;;
    "copy-id")
        copy_ssh_key
        ;;
    "logs")
        show_logs
        ;;
    "status")
        show_status
        ;;
    "reboot")
        reboot_pi
        ;;
    "shutdown")
        shutdown_pi
        ;;
    "-h"|"--help"|"help")
        usage
        exit 0
        ;;
    *)
        printf "Error: Unknown command '$COMMAND'\n" >&2
        usage
        exit 1
        ;;
esac
