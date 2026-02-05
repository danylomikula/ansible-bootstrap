#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${1:-${GITHUB_RUN_ID:-}}"

if [[ -z "${RUN_ID}" ]]; then
  echo "RUN_ID is required (argument or GITHUB_RUN_ID)." >&2
  exit 1
fi

if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
  echo "HCLOUD_TOKEN is required." >&2
  exit 1
fi

if ! command -v hcloud >/dev/null 2>&1; then
  echo "Missing required command: hcloud" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing required command: jq" >&2
  exit 1
fi

PREFIX="ci-${RUN_ID}-"

echo "Cleaning up Hetzner resources with prefix: ${PREFIX}"

mapfile -t SERVER_IDS < <(hcloud server list --output json | jq -r --arg prefix "${PREFIX}" '.[] | select(.name | startswith($prefix)) | .id')
for server_id in "${SERVER_IDS[@]}"; do
  if [[ -n "${server_id}" ]]; then
    hcloud server delete "${server_id}" || true
  fi
done

mapfile -t SSH_KEY_IDS < <(hcloud ssh-key list --output json | jq -r --arg prefix "${PREFIX}" '.[] | select(.name | startswith($prefix)) | .id')
for ssh_key_id in "${SSH_KEY_IDS[@]}"; do
  if [[ -n "${ssh_key_id}" ]]; then
    hcloud ssh-key delete "${ssh_key_id}" || true
  fi
done
