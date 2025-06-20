#!/bin/bash
set -e           # Exit on error
set -u           # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Configuration
readonly SSH_KEY_PATH="${HOME}/.ssh/panic_rpi_ssh"
readonly SSH_PORT="5555"
readonly MAX_WAIT_TIME=1800  # 30 minutes max wait
readonly CHECK_INTERVAL=30   # Check every 30 seconds

# Function to log with timestamp
log() {
    printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*"
}

# Function to test SSH connection
test_ssh() {
    ssh -i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null panic@localhost "echo 'SSH OK'" 2>/dev/null
}

# Function to check if setup is complete
check_setup_complete() {
    ssh -i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null panic@localhost "test -f /home/panic/.kiosk-setup-complete" 2>/dev/null
}

# Function to check if packages are installed
check_packages_installed() {
    ssh -i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null panic@localhost "dpkg -l | grep -q chromium-browser && dpkg -l | grep -q lxde" 2>/dev/null
}

# Function to get system status
get_system_status() {
    ssh -i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null panic@localhost "
        echo '=== System Status ==='
        uptime
        echo '=== Setup Service Status ==='
        systemctl is-active kiosk-setup 2>/dev/null || echo 'kiosk-setup service not active'
        echo '=== Package Installation Status ==='
        if dpkg -l | grep -q chromium-browser; then echo 'Chromium: INSTALLED'; else echo 'Chromium: NOT INSTALLED'; fi
        if dpkg -l | grep -q lxde; then echo 'LXDE: INSTALLED'; else echo 'LXDE: NOT INSTALLED'; fi
        echo '=== Setup Complete Marker ==='
        if test -f /home/panic/.kiosk-setup-complete; then echo 'Setup: COMPLETE'; else echo 'Setup: IN PROGRESS'; fi
        echo '=== Recent Logs ==='
        journalctl -u kiosk-setup --no-pager --lines=5 2>/dev/null || echo 'No kiosk-setup logs found'
    " 2>/dev/null
}

# Function to shutdown Pi
shutdown_pi() {
    log "Shutting down Pi..."
    ssh -i "${SSH_KEY_PATH}" -p "${SSH_PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null panic@localhost "sudo shutdown -h now" 2>/dev/null || true
}

# Main monitoring function
monitor_setup() {
    local start_time
    local elapsed_time
    local ssh_connected=false
    local setup_complete=false

    start_time=$(date +%s)

    log "Starting automated setup monitoring..."
    log "Max wait time: ${MAX_WAIT_TIME} seconds ($(($MAX_WAIT_TIME / 60)) minutes)"
    log "Check interval: ${CHECK_INTERVAL} seconds"
    log "SSH connection: panic@localhost:${SSH_PORT}"

    while true; do
        elapsed_time=$(( $(date +%s) - start_time ))

        # Check timeout
        if [[ $elapsed_time -gt $MAX_WAIT_TIME ]]; then
            log "ERROR: Maximum wait time exceeded (${MAX_WAIT_TIME}s)"
            log "Setup may have failed or is taking longer than expected"
            return 1
        fi

        # Show progress
        log "Elapsed: ${elapsed_time}s / ${MAX_WAIT_TIME}s"

        # Test SSH connection
        if test_ssh >/dev/null 2>&1; then
            if [[ "$ssh_connected" == false ]]; then
                log "✅ SSH connection established!"
                ssh_connected=true
            fi

            # Get and display system status
            log "Getting system status..."
            if ! get_system_status; then
                log "Failed to get system status, but SSH is working"
            fi

            # Check if setup is complete
            if check_setup_complete >/dev/null 2>&1; then
                if check_packages_installed >/dev/null 2>&1; then
                    log "✅ Setup complete! Packages installed and setup marker found."
                    setup_complete=true
                    break
                else
                    log "⚠️  Setup marker found but packages not fully installed. Waiting..."
                fi
            else
                log "🔄 Setup still in progress..."
            fi
        else
            if [[ "$ssh_connected" == true ]]; then
                log "⚠️  Lost SSH connection, Pi may be rebooting..."
                ssh_connected=false
            else
                log "🔄 Waiting for SSH connection..."
            fi
        fi

        log "Sleeping ${CHECK_INTERVAL} seconds..."
        sleep "${CHECK_INTERVAL}"
    done

    if [[ "$setup_complete" == true ]]; then
        log "🎉 Pi setup completed successfully!"
        log "Initiating shutdown..."
        shutdown_pi

        # Wait for shutdown
        log "Waiting for Pi to shut down..."
        local shutdown_wait=0
        while test_ssh >/dev/null 2>&1; do
            sleep 5
            shutdown_wait=$((shutdown_wait + 5))
            if [[ $shutdown_wait -gt 60 ]]; then
                log "⚠️  Pi is taking a long time to shut down"
                break
            fi
        done

        log "✅ Pi has shut down"
        return 0
    else
        log "❌ Setup did not complete successfully"
        return 1
    fi
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [options]

Automated monitoring script for Pi setup in QEMU.
Monitors SSH connection and checks for setup completion.

Options:
  -h, --help     Show this help message
  -t, --test     Test SSH connection only
  -s, --status   Get current system status
  --shutdown     Shutdown the Pi

Examples:
  $0              # Monitor setup automatically
  $0 --test       # Test SSH connection
  $0 --status     # Get system status
  $0 --shutdown   # Shutdown Pi
EOF
}

# Parse command line arguments
case "${1:-monitor}" in
    "monitor")
        monitor_setup
        ;;
    "-t"|"--test")
        log "Testing SSH connection..."
        if test_ssh; then
            log "✅ SSH connection successful"
            exit 0
        else
            log "❌ SSH connection failed"
            exit 1
        fi
        ;;
    "-s"|"--status")
        log "Getting system status..."
        if get_system_status; then
            exit 0
        else
            log "❌ Failed to get system status"
            exit 1
        fi
        ;;
    "--shutdown")
        shutdown_pi
        exit 0
        ;;
    "-h"|"--help")
        usage
        exit 0
        ;;
    *)
        log "Error: Unknown command '$1'"
        usage
        exit 1
        ;;
esac
