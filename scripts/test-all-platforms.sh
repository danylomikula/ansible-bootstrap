#!/usr/bin/env bash
#
# Run Molecule Hetzner scenarios across distro/scenario matrix.
#
# Usage examples:
#   HCLOUD_TOKEN=... ./scripts/test-all-platforms.sh
#   HCLOUD_TOKEN=... ./scripts/test-all-platforms.sh --scenario network --platform ubuntu2404
#   HCLOUD_TOKEN=... ./scripts/test-all-platforms.sh converge --scenario default
#

set -euo pipefail

# Initialize pyenv if available
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

DISTROS=(
  "debian13"
  "ubuntu2404"
  "rockylinux10"
)

SCENARIOS=(
  "default"
  "minimal"
  "ssh-generate"
  "full"
  "network"
  "expand-fs"
  "reboot"
)

MOLECULE_COMMAND="test"
SINGLE_SCENARIO=""
SINGLE_DISTRO=""
STOP_ON_FAILURE="${STOP_ON_FAILURE:-true}"

HCLOUD_SERVER_TYPE="${HCLOUD_SERVER_TYPE:-cx33}"
HCLOUD_LOCATION="${HCLOUD_LOCATION:-hel1}"
HCLOUD_FALLBACK_LOCATIONS="${HCLOUD_FALLBACK_LOCATIONS:-fsn1,nbg1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RESULTS_NAME=()
RESULTS_STATUS=()
RESULTS_TIME=()

usage() {
  echo "Usage: $0 [OPTIONS] [MOLECULE_COMMAND]"
  echo ""
  echo "Options:"
  echo "  --scenario NAME     Run only specific scenario on all distros"
  echo "  --platform NAME     Run all scenarios on specific distro"
  echo "  --list-scenarios    List available scenarios"
  echo "  --list-platforms    List available distros"
  echo "  -h, --help          Show this help"
  echo ""
  echo "Molecule commands: test, converge, verify, destroy, etc."
  echo ""
  echo "Required environment:"
  echo "  HCLOUD_TOKEN        Hetzner Cloud API token"
  echo ""
  echo "Optional environment:"
  echo "  HCLOUD_SERVER_TYPE=${HCLOUD_SERVER_TYPE}"
  echo "  HCLOUD_LOCATION=${HCLOUD_LOCATION}"
  echo "  HCLOUD_FALLBACK_LOCATIONS=${HCLOUD_FALLBACK_LOCATIONS}"
  echo "  STOP_ON_FAILURE=${STOP_ON_FAILURE}"
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

is_supported_combo() {
  local distro="$1"
  local scenario="$2"

  # Network scenario is Debian/Ubuntu only in this project.
  if [[ "${scenario}" == "network" && "${distro}" == "rockylinux10" ]]; then
    return 1
  fi

  return 0
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

  if \
    ANSIBLE_LOCAL_TEMP=/tmp/ansible-local \
    ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote \
    ANSIBLE_HOME=/tmp/.ansible \
    MOLECULE_HCLOUD_DISTRO="${distro}" \
    MOLECULE_HCLOUD_SCENARIO="${scenario}" \
    HCLOUD_SERVER_TYPE="${HCLOUD_SERVER_TYPE}" \
    HCLOUD_LOCATION="${HCLOUD_LOCATION}" \
    HCLOUD_FALLBACK_LOCATIONS="${HCLOUD_FALLBACK_LOCATIONS}" \
    molecule "${MOLECULE_COMMAND}" -s hetzner; then
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

    if [[ "${status}" == "PASS" ]]; then
      echo -e "${GREEN}[PASS]${NC} ${name} (${duration}s)"
      ((passed++))
    else
      echo -e "${RED}[FAIL]${NC} ${name} (${duration}s)"
      ((failed++))
    fi
  done

  local total=${#RESULTS_NAME[@]}
  echo ""
  echo "----------------------------------------------"
  echo "Passed: ${passed}/${total}"
  echo "Failed: ${failed}/${total}"
  echo "----------------------------------------------"

  if [[ ${failed} -gt 0 ]]; then
    return 1
  fi
  return 0
}

test_all() {
  local scenarios_to_test=("${SCENARIOS[@]}")
  local distros_to_test=("${DISTROS[@]}")

  if [[ -n "${SINGLE_SCENARIO}" ]]; then
    scenarios_to_test=("${SINGLE_SCENARIO}")
  fi

  if [[ -n "${SINGLE_DISTRO}" ]]; then
    distros_to_test=("${SINGLE_DISTRO}")
  fi

  local total_tests=0
  local scenario
  local distro
  for scenario in "${scenarios_to_test[@]}"; do
    for distro in "${distros_to_test[@]}"; do
      if is_supported_combo "${distro}" "${scenario}"; then
        total_tests=$((total_tests + 1))
      fi
    done
  done

  log_info "Running ${total_tests} Molecule tests"
  echo ""

  local has_failures=false
  local current=0

  for scenario in "${scenarios_to_test[@]}"; do
    log_scenario "=== Scenario: ${scenario} ==="
    for distro in "${distros_to_test[@]}"; do
      if ! is_supported_combo "${distro}" "${scenario}"; then
        log_warning "Skipping unsupported combo ${scenario}/${distro}"
        continue
      fi

      current=$((current + 1))
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      SINGLE_SCENARIO="$2"
      shift 2
      ;;
    --platform)
      SINGLE_DISTRO="$2"
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
      echo "Available distros:"
      for d in "${DISTROS[@]}"; do
        echo "  - ${d}"
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

main() {
  if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    echo "HCLOUD_TOKEN is required." >&2
    exit 1
  fi

  log_info "Molecule command: ${MOLECULE_COMMAND}"
  log_info "Hetzner server type: ${HCLOUD_SERVER_TYPE}"
  log_info "Hetzner location: ${HCLOUD_LOCATION}"
  log_info "Hetzner fallback locations: ${HCLOUD_FALLBACK_LOCATIONS}"
  if [[ -n "${SINGLE_SCENARIO}" ]]; then
    log_info "Scenario filter: ${SINGLE_SCENARIO}"
  fi
  if [[ -n "${SINGLE_DISTRO}" ]]; then
    log_info "Distro filter: ${SINGLE_DISTRO}"
  fi
  echo ""

  test_all
  print_summary
}

main
