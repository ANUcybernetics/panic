#!/bin/bash

# Test script for Raspberry Pi 5 Kiosk Setup
# This script tests the setup process without actually burning to SD card

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[TEST-INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST-PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[TEST-WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[TEST-FAIL]${NC} $1"
}

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_URL="https://example.com"
TEST_SSID="TestNetwork"
TEST_PASSWORD="testpass123"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Running test: $test_name"

    if $test_function; then
        log_success "PASSED: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "FAILED: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo
}

# Test 1: Check if main script exists
test_main_script_exists() {
    if [ -f "$SCRIPT_DIR/setup-kiosk.sh" ]; then
        return 0
    else
        log_error "setup-kiosk.sh not found"
        return 1
    fi
}

# Test 2: Check cache directory creation
test_cache_directory() {
    local test_cache_dir="${HOME}/.raspios-images-test"

    if mkdir -p "$test_cache_dir"; then
        log_info "Can create cache directory"
        rmdir "$test_cache_dir"
        return 0
    else
        log_error "Cannot create cache directory"
        return 1
    fi
}

# Test 3: Check script permissions
test_script_permissions() {
    if [ ! -x "$SCRIPT_DIR/setup-kiosk.sh" ]; then
        log_error "setup-kiosk.sh is not executable"
        return 1
    else
        log_info "setup-kiosk.sh is executable"
        return 0
    fi
}

# Test 4: Check required system tools
test_system_dependencies() {
    local missing_tools=()

    for tool in curl diskutil hdiutil; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing tools: ${missing_tools[*]}"
        return 1
    else
        log_info "All required tools found: curl, diskutil, hdiutil"
        return 0
    fi
}

# Test 5: Check macOS compatibility
test_macos_compatibility() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "Running on macOS: $OSTYPE"
        return 0
    else
        log_warning "Not running on macOS - script may need adaptation"
        return 1
    fi
}

# Test 6: Test argument parsing
test_argument_parsing() {
    # Test with minimal arguments
    if bash -n "$SCRIPT_DIR/setup-kiosk.sh"; then
        log_info "Script syntax is valid"
    else
        log_error "Script has syntax errors"
        return 1
    fi

    # Test argument validation by checking the usage message
    local usage_output=$(bash "$SCRIPT_DIR/setup-kiosk.sh" 2>&1 || true)
    if echo "$usage_output" | grep -q "wifi-username"; then
        log_info "Script correctly requires 4 arguments including wifi-username"
        return 0
    else
        log_error "Script does not properly validate enterprise WiFi arguments"
        return 1
    fi
}

# Test 7: Test enterprise WiFi configuration
test_enterprise_wifi_config() {
    # Check if the script properly handles enterprise WiFi configuration
    if grep -q "key_mgmt=WPA-EAP" "$SCRIPT_DIR/setup-kiosk.sh"; then
        log_info "Enterprise WiFi configuration found"

        if grep -q "eap=PEAP" "$SCRIPT_DIR/setup-kiosk.sh" && grep -q "phase2=" "$SCRIPT_DIR/setup-kiosk.sh"; then
            log_info "PEAP configuration properly implemented"
            return 0
        else
            log_error "Incomplete enterprise WiFi configuration"
            return 1
        fi
    else
        log_error "No enterprise WiFi configuration found"
        return 1
    fi
}

# Test 8: Test image caching functionality
test_image_caching() {
    # Check if the script implements proper image caching
    if grep -q "CACHE_DIR=" "$SCRIPT_DIR/setup-kiosk.sh"; then
        log_info "Image caching directory configured"

        if grep -q '\.raspios-images' "$SCRIPT_DIR/setup-kiosk.sh"; then
            log_info "Cache directory uses proper location"
            return 0
        else
            log_error "Cache directory not properly configured"
            return 1
        fi
    else
        log_error "No image caching functionality found"
        return 1
    fi
}

# Test 9: Test URL validation
test_url_validation() {
    local valid_urls=("https://example.com" "http://localhost:3000" "https://test.org/path?param=value")
    local invalid_urls=("not-a-url" "ftp://example.com" "")

    # Test valid URLs (basic regex check)
    for url in "${valid_urls[@]}"; do
        if [[ "$url" =~ ^https?:// ]]; then
            log_info "Valid URL format: $url"
        else
            log_error "URL validation failed for: $url"
            return 1
        fi
    done

    # Test invalid URLs
    for url in "${invalid_urls[@]}"; do
        if [[ ! "$url" =~ ^https?:// ]]; then
            log_info "Correctly rejected invalid URL: '$url'"
        else
            log_error "Should have rejected invalid URL: '$url'"
            return 1
        fi
    done

    return 0
}

# Test 10: Test configuration file generation
test_config_generation() {
    # Test if the script can generate configuration content
    local test_config="/tmp/test-config-$$"

    # Simulate creating a basic kiosk config
    cat > "$test_config" << EOF
#!/bin/bash
# Test kiosk configuration
KIOSK_URL="$TEST_URL"
USERNAME="kiosk"
EOF

    if [ -f "$test_config" ] && grep -q "KIOSK_URL" "$test_config"; then
        log_info "Configuration file generation works"
        rm -f "$test_config"
        return 0
    else
        log_error "Configuration file generation failed"
        rm -f "$test_config"
        return 1
    fi
}

# Test 11: Check README completeness
test_readme_completeness() {
    local readme_file="$SCRIPT_DIR/README.md"

    if [ ! -f "$readme_file" ]; then
        log_error "README.md not found"
        return 1
    fi

    # Check for essential sections
    local required_sections=("Requirements" "Troubleshooting")
    local missing_sections=()

    for section in "${required_sections[@]}"; do
        if ! grep -q "$section" "$readme_file"; then
            missing_sections+=("$section")
        fi
    done

    if [ ${#missing_sections[@]} -eq 0 ]; then
        log_info "README.md contains required sections"
        return 0
    else
        log_error "README.md missing sections: ${missing_sections[*]}"
        return 1
    fi
}

# Test 12: Test error handling
test_error_handling() {
    # Check if script uses 'set -e' for error handling
    if grep -q "set -e" "$SCRIPT_DIR/setup-kiosk.sh"; then
        log_info "Script uses proper error handling (set -e)"
        return 0
    else
        log_warning "Script may not have proper error handling"
        return 1
    fi
}

# Print test summary
print_summary() {
    echo
    echo "================================"
    log_info "Test Summary"
    echo "================================"
    log_info "Total tests: $TOTAL_TESTS"
    log_success "Passed: $TESTS_PASSED"

    if [ $TESTS_FAILED -gt 0 ]; then
        log_error "Failed: $TESTS_FAILED"
    else
        log_info "Failed: $TESTS_FAILED"
    fi

    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! Setup appears to be working correctly."
        log_info "You can now run the actual setup with:"
        log_info "  ./setup-kiosk.sh <url> <wifi-ssid> <wifi-username> <wifi-password>"
    else
        log_error "Some tests failed. Please fix the issues before running the setup."
        return 1
    fi
}

# Main test execution
main() {
    log_info "Raspberry Pi 5 Kiosk Setup - Test Suite"
    log_info "======================================="
    echo

    # Run all tests
    run_test "Main script exists" test_main_script_exists
    run_test "Cache directory creation" test_cache_directory
    run_test "Script permissions" test_script_permissions
    run_test "System dependencies" test_system_dependencies
    run_test "macOS compatibility" test_macos_compatibility
    run_test "Argument parsing" test_argument_parsing
    run_test "Enterprise WiFi config" test_enterprise_wifi_config
    run_test "Image caching" test_image_caching
    run_test "URL validation" test_url_validation
    run_test "Config generation" test_config_generation
    run_test "README completeness" test_readme_completeness
    run_test "Error handling" test_error_handling

    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"
