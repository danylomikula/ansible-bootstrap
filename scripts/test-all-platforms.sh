#!/usr/bin/env bash
#
# Run molecule tests on all supported platforms and scenarios
#
# Usage:
#   ./scripts/test-all-platforms.sh                    # Test ALL scenarios on ALL platforms
#   ./scripts/test-all-platforms.sh converge           # Only converge (no destroy)
#   ./scripts/test-all-platforms.sh --scenario ipv6    # Test specific scenario on all platforms
#   ./scripts/test-all-platforms.sh --platform debian13  # Test all scenarios on specific platform
#   STOP_ON_FAILURE=false ./scripts/test-all-platforms.sh  # Continue on errors
#

set -euo pipefail

# Initialize pyenv if available
if command -v pyenv &>/dev/null; then
    eval "$(pyenv init -)"
fi

# =============================================================================
# SUPPORTED PLATFORMS
# Add or remove distributions here to control which platforms are tested
# =============================================================================
PLATFORMS=(
    "debian13"
    "ubuntu2404"
    "rockylinux10"
)

# =============================================================================
# AVAILABLE SCENARIOS
# Add new scenarios here as they are created
# =============================================================================
SCENARIOS=(
    "default"       # Standard config: user, SSH hardening, hostname, firewall
    "minimal"       # Minimal: only user creation
    "ssh-generate"  # SSH key generation test
    "full"          # Full config: custom groups, SSH port, firewall ports
)

# =============================================================================
# Configuration
# =============================================================================
MOLECULE_COMMAND="test"
SINGLE_SCENARIO=""
SINGLE_PLATFORM=""
STOP_ON_FAILURE="${STOP_ON_FAILURE:-true}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Results tracking (simple arrays for bash 3 compatibility)
RESULTS_NAME=()
RESULTS_STATUS=()
RESULTS_TIME=()

# =============================================================================
# Functions
# =============================================================================
usage() {
    echo "Usage: $0 [OPTIONS] [MOLECULE_COMMAND]"
    echo ""
    echo "Options:"
    echo "  --scenario NAME     Run only specific scenario on all platforms"
    echo "  --platform NAME     Run all scenarios on specific platform only"
    echo "  --list-scenarios    List available scenarios"
    echo "  --list-platforms    List available platforms"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Molecule commands: test, converge, verify, destroy, etc."
    echo ""
    echo "Environment variables:"
    echo "  STOP_ON_FAILURE=false  Continue testing after failures"
    echo ""
    echo "Examples:"
    echo "  $0                           # Test ALL scenarios on ALL platforms"
    echo "  $0 --scenario ipv6           # Test only ipv6 scenario on all platforms"
    echo "  $0 --platform debian13       # Test all scenarios on debian13 only"
    echo "  $0 converge                  # Only converge, no destroy"
    exit 0
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_scenario() {
    echo -e "${CYAN}[SCENARIO]${NC} $1"
}

run_test() {
    local name="$1"
    local distro="$2"
    local scenario="$3"
    local start_time
    local end_time
    local duration

    log_info "Testing: ${name}"
    start_time=$(date +%s)

    if MOLECULE_DISTRO="${distro}" molecule "${MOLECULE_COMMAND}" -s "${scenario}" 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        RESULTS_NAME+=("${name}")
        RESULTS_STATUS+=("PASS")
        RESULTS_TIME+=("${duration}")
        log_success "${name} completed in ${duration}s"
        return 0
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        RESULTS_NAME+=("${name}")
        RESULTS_STATUS+=("FAIL")
        RESULTS_TIME+=("${duration}")
        log_error "${name} failed after ${duration}s"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "TEST SUMMARY"
    echo "=============================================="
    echo ""

    local passed=0
    local failed=0
    local i

    for i in "${!RESULTS_NAME[@]}"; do
        local name="${RESULTS_NAME[$i]}"
        local status="${RESULTS_STATUS[$i]}"
        local duration="${RESULTS_TIME[$i]}"

        if [[ "$status" == "PASS" ]]; then
            echo -e "${GREEN}✓${NC} ${name}: PASS (${duration}s)"
            ((passed++))
        else
            echo -e "${RED}✗${NC} ${name}: FAIL (${duration}s)"
            ((failed++))
        fi
    done

    local total=${#RESULTS_NAME[@]}
    echo ""
    echo "----------------------------------------------"
    echo "Passed: ${passed}/${total}"
    echo "Failed: ${failed}/${total}"
    echo "----------------------------------------------"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

test_all() {
    local scenarios_to_test=("${SCENARIOS[@]}")
    local platforms_to_test=("${PLATFORMS[@]}")

    # Filter to single scenario if specified
    if [[ -n "${SINGLE_SCENARIO}" ]]; then
        scenarios_to_test=("${SINGLE_SCENARIO}")
    fi

    # Filter to single platform if specified
    if [[ -n "${SINGLE_PLATFORM}" ]]; then
        platforms_to_test=("${SINGLE_PLATFORM}")
    fi

    local total_tests=$((${#scenarios_to_test[@]} * ${#platforms_to_test[@]}))
    log_info "Running ${total_tests} tests (${#scenarios_to_test[@]} scenarios x ${#platforms_to_test[@]} platforms)"
    echo ""

    local has_failures=false
    local current=0

    for scenario in "${scenarios_to_test[@]}"; do
        log_scenario "=== Scenario: ${scenario} ==="
        for distro in "${platforms_to_test[@]}"; do
            ((current++))
            local test_name="${scenario}/${distro}"
            log_info "[${current}/${total_tests}] ${test_name}"
            if ! run_test "${test_name}" "${distro}" "${scenario}"; then
                has_failures=true
                if [[ "${STOP_ON_FAILURE}" == "true" ]]; then
                    log_warning "Stopping due to failure (set STOP_ON_FAILURE=false to continue)"
                    return 1
                fi
            fi
            echo ""
        done
    done

    if [[ "${has_failures}" == "true" ]]; then
        return 1
    fi
    return 0
}

# =============================================================================
# Parse Arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --scenario)
            SINGLE_SCENARIO="$2"
            shift 2
            ;;
        --platform)
            SINGLE_PLATFORM="$2"
            shift 2
            ;;
        --list-scenarios)
            echo "Available scenarios:"
            for s in "${SCENARIOS[@]}"; do
                echo "  - ${s}"
            done
            exit 0
            ;;
        --list-platforms)
            echo "Available platforms:"
            for p in "${PLATFORMS[@]}"; do
                echo "  - ${p}"
            done
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            MOLECULE_COMMAND="$1"
            shift
            ;;
    esac
done

# =============================================================================
# Main
# =============================================================================
main() {
    log_info "Molecule command: ${MOLECULE_COMMAND}"
    if [[ -n "${SINGLE_SCENARIO}" ]]; then
        log_info "Scenario filter: ${SINGLE_SCENARIO}"
    fi
    if [[ -n "${SINGLE_PLATFORM}" ]]; then
        log_info "Platform filter: ${SINGLE_PLATFORM}"
    fi
    echo ""

    test_all
    print_summary
}

main
