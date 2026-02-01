# Ansible Bootstrap

[![CI](https://img.shields.io/github/actions/workflow/status/danylomikula/ansible-bootstrap/pr-validation.yml?label=CI)](https://github.com/danylomikula/ansible-bootstrap/actions/workflows/pr-validation.yml)
[![Release](https://img.shields.io/github/v/release/danylomikula/ansible-bootstrap)](https://github.com/danylomikula/ansible-bootstrap/releases)
[![Ansible Galaxy](https://img.shields.io/badge/galaxy-danylomikula.ansible__bootstrap-blue.svg)](https://galaxy.ansible.com/ui/repo/published/danylomikula/ansible_bootstrap/)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Ansible](https://img.shields.io/badge/ansible-2.15+-blue.svg)](https://www.ansible.com/)

Universal server bootstrap playbook for initial server configuration.

## Supported Platforms

- Debian 13
- Ubuntu 24.04
- Rocky Linux 10

## Installation

### From Ansible Galaxy

```bash
ansible-galaxy collection install danylomikula.ansible_bootstrap
```

Or add to your project's `requirements.yml`:

```yaml
---
collections:
  - name: danylomikula.ansible_bootstrap
    version: ">=1.0.0"
```

Then install:

```bash
ansible-galaxy collection install -r requirements.yml
```

### From Source

```bash
git clone https://github.com/danylomikula/ansible-bootstrap.git
cd ansible-bootstrap
ansible-galaxy collection install -r requirements.yml
```

## Quick Start

### Using from Ansible Galaxy

Create a playbook `bootstrap.yml`:

```yaml
---
- name: Bootstrap servers
  hosts: all
  become: true
  vars:
    bootstrap_user: "admin"
    bootstrap_ssh_key_generate: true
    bootstrap_firewall_enabled: true
    bootstrap_reboot_enabled: true
  roles:
    - danylomikula.ansible_bootstrap.bootstrap
```

Run the playbook:

```bash
ansible-playbook -i inventory.ini bootstrap.yml -k -K
```

### Using from Source

```bash
# Copy and edit inventory
cp inventory.ini.example inventory.ini

# Edit group_vars/all/vars.yml with your settings

# Run playbook (see First Run section below)
ansible-playbook -i inventory.ini site.yml
```

## First Run

On first run, when hosts don't have SSH keys configured yet:

```bash
# With password authentication
ansible-playbook -i inventory.ini site.yml --ask-pass --ask-become-pass

# Or shorter
ansible-playbook -i inventory.ini site.yml -k -K
```

After bootstrap completes, SSH keys are deployed. Update inventory with key paths:

```ini
[servers]
server01 ansible_host=10.20.0.50 ansible_ssh_private_key_file=./ssh_keys/server01_ed25519

[servers:vars]
ansible_user=admin
```

## Features

- User creation with sudo access
- SSH key generation and deployment
- SSH hardening (disable password auth, root login)
- Static IPv4/IPv6 network configuration
- Firewall (firewalld) with custom zones
- Hostname configuration
- Filesystem expansion

## Example Inventory

```ini
[servers]
pihole-master ansible_host=10.20.160.250 bootstrap_static_ip=10.20.0.50/16 bootstrap_gateway=10.20.0.1 bootstrap_static_ip6=fda3:6tgc:b944:20::50/64 bootstrap_gateway6=fda3:6tgc:b944:20::1
pihole-backup ansible_host=10.20.200.38 bootstrap_static_ip=10.20.0.51/16 bootstrap_gateway=10.20.0.1 bootstrap_static_ip6=fda3:6tgc:b944:20::51/64 bootstrap_gateway6=fda3:6tgc:b944:20::1

[servers:vars]
ansible_user=ansible
```

## Project Structure

```
ansible-bootstrap/
├── site.yml                 # Main playbook
├── requirements.yml         # Ansible Galaxy dependencies
├── inventory.ini.example    # Example inventory
├── group_vars/
│   └── all/
│       └── vars.yml         # Default variables
└── roles/
    └── bootstrap/           # Main role
        ├── defaults/        # Default variables
        ├── tasks/           # Task files
        ├── handlers/        # Handlers
        └── meta/            # Galaxy metadata
```

## Configuration

See [roles/bootstrap/README.md](roles/bootstrap/README.md) for detailed configuration options.

## Testing

```bash
# Run all tests on all platforms
./scripts/test-all-platforms.sh

# Test specific scenario
./scripts/test-all-platforms.sh --scenario full

# Test specific platform
./scripts/test-all-platforms.sh --platform debian13

# List available scenarios and platforms
./scripts/test-all-platforms.sh --list-scenarios
./scripts/test-all-platforms.sh --list-platforms
```

## License

Apache 2.0 Licensed. See [LICENSE](LICENSE) for full details.

## Authors

Role managed by [Danylo Mikula](https://github.com/danylomikula).
