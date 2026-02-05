#!/usr/bin/env bash
set -euo pipefail

DISTRO="${1:?Usage: run-hetzner-scenario.sh <distro> <scenario>}"
SCENARIO="${2:?Usage: run-hetzner-scenario.sh <distro> <scenario>}"

PROJECT_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_DIR="$(mktemp -d)"
KEY_PATH="${TMP_DIR}/ci_id_ed25519"
INVENTORY_PATH="${TMP_DIR}/inventory.ini"
LOG_DIR="${PROJECT_DIR}/.ci_artifacts"
mkdir -p "${LOG_DIR}"
RUN_LOG="${LOG_DIR}/${DISTRO}-${SCENARIO}-runner.log"
touch "${RUN_LOG}"
exec > >(tee -a "${RUN_LOG}") 2>&1

HCLOUD_SERVER_TYPE="${HCLOUD_SERVER_TYPE:-cx33}"
HCLOUD_LOCATION="${HCLOUD_LOCATION:-hel1}"
HCLOUD_FALLBACK_LOCATIONS="${HCLOUD_FALLBACK_LOCATIONS:-fsn1,nbg1}"

SERVER_NAME_BASE="ci-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-0}-${DISTRO}-${SCENARIO}"
SERVER_NAME="$(echo "${SERVER_NAME_BASE}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-')"
SERVER_NAME="${SERVER_NAME:0:60}"
KEY_NAME="${SERVER_NAME}-key"
SERVER_ID=""
SERVER_IP=""

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

cleanup() {
  set +e

  if [[ -n "${SERVER_ID}" ]]; then
    hcloud server delete "${SERVER_ID}" >/dev/null 2>&1 || true
  elif [[ -n "${SERVER_NAME}" ]]; then
    hcloud server delete "${SERVER_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${KEY_NAME}" ]]; then
    hcloud ssh-key delete "${KEY_NAME}" >/dev/null 2>&1 || true
  fi

  rm -rf "${PROJECT_DIR}/.ci_ssh_keys"
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

wait_for_ssh() {
  local ip="$1"
  local attempt

  for attempt in $(seq 1 60); do
    if ssh -i "${KEY_PATH}" \
      -o StrictHostKeyChecking=accept-new \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      "root@${ip}" "echo ready" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done

  return 1
}

wait_for_cloud_init() {
  if run_remote "command -v cloud-init >/dev/null 2>&1"; then
    echo "Waiting for cloud-init to finish..."
    run_remote "timeout 900 cloud-init status --wait >/dev/null 2>&1 || true"
  fi
}

map_distro_to_image() {
  case "$1" in
    debian13)
      echo "debian-13"
      ;;
    ubuntu2404)
      echo "ubuntu-24.04"
      ;;
    rockylinux10)
      echo "rocky-10"
      ;;
    *)
      echo "Unsupported distro: $1" >&2
      exit 1
      ;;
  esac
}

run_remote() {
  local command="$1"
  ssh -i "${KEY_PATH}" \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    "root@${SERVER_IP}" "${command}"
}

main() {
  local image
  local create_output=""
  local create_error
  local location
  local location_item
  local primary_iface
  local primary_ipv4
  local primary_gw
  local scenario_playbook
  local verify_playbook
  local -a hcloud_locations
  local -a hcloud_fallback_locations

  require_cmd hcloud
  require_cmd jq
  require_cmd ansible-playbook
  require_cmd ssh-keygen
  require_cmd ssh

  image="$(map_distro_to_image "${DISTRO}")"

  if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    echo "HCLOUD_TOKEN is required." >&2
    exit 1
  fi

  scenario_playbook="${PROJECT_DIR}/ci/scenarios/${SCENARIO}.yml"
  verify_playbook="${PROJECT_DIR}/ci/verify/${SCENARIO}.yml"
  if [[ ! -f "${scenario_playbook}" ]]; then
    echo "Missing scenario playbook: ${scenario_playbook}" >&2
    exit 1
  fi
  if [[ ! -f "${verify_playbook}" ]]; then
    echo "Missing verify playbook: ${verify_playbook}" >&2
    exit 1
  fi

  ssh-keygen -t ed25519 -N "" -f "${KEY_PATH}" -C "${KEY_NAME}" >/dev/null
  hcloud ssh-key create --name "${KEY_NAME}" --public-key-from-file "${KEY_PATH}.pub" >/dev/null

  hcloud_locations=("${HCLOUD_LOCATION}")
  IFS=',' read -r -a hcloud_fallback_locations <<< "${HCLOUD_FALLBACK_LOCATIONS}"
  for location_item in "${hcloud_fallback_locations[@]}"; do
    location="$(echo "${location_item}" | xargs)"
    if [[ -n "${location}" && "${location}" != "${HCLOUD_LOCATION}" ]]; then
      hcloud_locations+=("${location}")
    fi
  done

  for location in "${hcloud_locations[@]}"; do
    echo "Attempting Hetzner server create in location ${location}..."
    if create_output="$(
      hcloud server create \
        --name "${SERVER_NAME}" \
        --type "${HCLOUD_SERVER_TYPE}" \
        --image "${image}" \
        --location "${location}" \
        --ssh-key "${KEY_NAME}" \
        --output json 2>"${TMP_DIR}/hcloud-create-error.log"
    )"; then
      HCLOUD_LOCATION="${location}"
      break
    fi

    create_error="$(cat "${TMP_DIR}/hcloud-create-error.log" 2>/dev/null || true)"
    if echo "${create_error}" | grep -q "resource_unavailable"; then
      echo "Capacity unavailable in ${location}, trying next location..."
      continue
    fi

    echo "Hetzner server create failed in ${location}:" >&2
    echo "${create_error}" >&2
    exit 1
  done

  if [[ -z "${create_output}" ]]; then
    echo "Failed to create Hetzner server in locations: ${hcloud_locations[*]}" >&2
    exit 1
  fi

  SERVER_ID="$(echo "${create_output}" | jq -r '.server.id')"
  SERVER_IP="$(echo "${create_output}" | jq -r '.server.public_net.ipv4.ip')"

  if [[ -z "${SERVER_ID}" || "${SERVER_ID}" == "null" || -z "${SERVER_IP}" || "${SERVER_IP}" == "null" ]]; then
    echo "Failed to create Hetzner server or parse server details." >&2
    exit 1
  fi

  echo "Provisioned ${SERVER_NAME} (${SERVER_IP}) for ${DISTRO}/${SCENARIO} in ${HCLOUD_LOCATION}"

  if ! wait_for_ssh "${SERVER_IP}"; then
    echo "Server did not become reachable over SSH in time." >&2
    exit 1
  fi

  wait_for_cloud_init

  primary_iface="$(
    run_remote "ip -o route show default | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\"){print \$(i+1); exit}}'" | tr -d '\r'
  )"
  if [[ -z "${primary_iface}" || "${primary_iface}" == "lo" ]]; then
    primary_iface="$(
      run_remote "ip -o route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\"){print \$(i+1); exit}}'" | tr -d '\r'
    )"
  fi
  if [[ -z "${primary_iface}" || "${primary_iface}" == "lo" ]]; then
    echo "Unable to detect a valid primary network interface (got: '${primary_iface}')." >&2
    exit 1
  fi

  primary_gw="$(run_remote "ip -o route show default | awk '{for(i=1;i<=NF;i++) if(\$i==\"via\"){print \$(i+1); exit}}'" | tr -d '\r')"
  if [[ -z "${primary_gw}" ]]; then
    primary_gw="$(run_remote "ip -o route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if(\$i==\"via\"){print \$(i+1); exit}}'" | tr -d '\r')"
  fi

  primary_ipv4="$(run_remote "ip -4 -o addr show dev ${primary_iface} scope global | awk '{print \$4}' | head -1" | tr -d '\r')"
  if [[ -z "${primary_ipv4}" ]]; then
    echo "Unable to detect IPv4 CIDR on interface ${primary_iface}." >&2
    exit 1
  fi

  cat > "${INVENTORY_PATH}" <<EOF
[targets]
target ansible_host=${SERVER_IP} ansible_user=root ansible_ssh_private_key_file=${KEY_PATH} ci_primary_iface=${primary_iface} ci_primary_ipv4_cidr=${primary_ipv4} ci_primary_gateway=${primary_gw}
EOF

  export CI_PROJECT_DIR="${PROJECT_DIR}"
  export ANSIBLE_LOCAL_TEMP="/tmp/ansible-local"
  export ANSIBLE_REMOTE_TEMP="/tmp/ansible-remote"
  export ANSIBLE_ROLES_PATH="${PROJECT_DIR}/roles"

  ansible-playbook -i "${INVENTORY_PATH}" "${scenario_playbook}" | tee "${LOG_DIR}/${DISTRO}-${SCENARIO}-converge.log"
  ansible-playbook -i "${INVENTORY_PATH}" "${verify_playbook}" | tee "${LOG_DIR}/${DISTRO}-${SCENARIO}-verify.log"
}

main "$@"
