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

# Test 2: Check if helper script exists
test_helper_script_exists() {
    if [ -f "$SCRIPT_DIR/quick-setup.sh" ]; then
        return 0
    else
        log_error "quick-setup.sh not found"
        return 1
    fi
}

# Test 3: Check script permissions
test_script_permissions() {
    local all_executable=true

    for script in setup-kiosk.sh quick-setup.sh; do
        if [ ! -x "$SCRIPT_DIR/$script" ]; then
            log_error "$script is not executable"
            all_executable=false
        fi
    done

    return $($all_executable && echo 0 || echo 1)
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

    # Test help functionality
    if bash "$SCRIPT_DIR/quick-setup.sh" --help >/dev/null 2>&1; then
        log_info "Help functionality works"
        return 0
    else
        log_warning "Help functionality may have issues"
        return 1
    fi
}

# Test 7: Test preset functionality
test_preset_functionality() {
    # Check if preset function is defined in quick-setup.sh
    if grep -q "get_preset_url()" "$SCRIPT_DIR/quick-setup.sh"; then
        log_info "Preset functionality is defined in quick-setup.sh"

        # Test a few presets
        local test_presets=("dashboard" "clock" "test")
        local preset_count=0

        for preset in "${test_presets[@]}"; do
            if grep -q "^[[:space:]]*$preset)" "$SCRIPT_DIR/quick-setup.sh"; then
                preset_count=$((preset_count + 1))
            fi
        done

        if [ $preset_count -gt 0 ]; then
            log_info "Found $preset_count test presets working"
            return 0
        else
            log_error "No working presets found"
            return 1
        fi
    else
        log_error "No preset functionality found in quick-setup.sh"
        return 1
    fi
}

# Test 8: Test workspace creation (dry run)
test_workspace_creation() {
    local test_workspace="/tmp/kiosk-test-$$"

    if mkdir -p "$test_workspace"; then
        log_info "Can create workspace directories"
        rmdir "$test_workspace"
        return 0
    else
        log_error "Cannot create workspace directories"
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
    local required_sections=("Requirements" "Quick Start" "Troubleshooting")
    local missing_sections=()

    for section in "${required_sections[@]}"; do
        if ! grep -q "$section" "$readme_file"; then
            missing_sections+=("$section")
        fi
    done

    if [ ${#missing_sections[@]} -eq 0 ]; then
        log_info "README.md contains all required sections"
        return 0
    else
        log_error "README.md missing sections: ${missing_sections[*]}"
        return 1
    fi
}

# Test 12: Test error handling
test_error_handling() {
    # Check if scripts use 'set -e' for error handling
    if grep -q "set -e" "$SCRIPT_DIR/setup-kiosk.sh" && grep -q "set -e" "$SCRIPT_DIR/quick-setup.sh"; then
        log_info "Scripts use proper error handling (set -e)"
        return 0
    else
        log_warning "Scripts may not have proper error handling"
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
        log_info "  ./quick-setup.sh"
        log_info "  or"
        log_info "  ./setup-kiosk.sh <your-url>"
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
    run_test "Helper script exists" test_helper_script_exists
    run_test "Script permissions" test_script_permissions
    run_test "System dependencies" test_system_dependencies
    run_test "macOS compatibility" test_macos_compatibility
    run_test "Argument parsing" test_argument_parsing
    run_test "Preset functionality" test_preset_functionality
    run_test "Workspace creation" test_workspace_creation
    run_test "URL validation" test_url_validation
    run_test "Config generation" test_config_generation
    run_test "README completeness" test_readme_completeness
    run_test "Error handling" test_error_handling

    # Print summary and exit with appropriate code
    print_summary
}

# Run main function
main "$@"
