# Bootstrap Role

Universal server bootstrap role for initial server configuration.

## Features

- **User Management**: Create admin user with sudo access
- **SSH Hardening**: Disable password auth, root login, custom port
- **SSH Key Generation**: Auto-generate ed25519/rsa keys locally
- **Hostname Configuration**: Set system hostname
- **Static Network**: Configure static IPv4/IPv6 via native OS backend (netplan/ifupdown on Debian-family, NetworkManager on RedHat)
- **Firewall**: Configure firewalld with services, ports, custom zones
- **Filesystem Expansion**: Expand root partition

## Supported Platforms

- Debian 13
- Ubuntu 24.04
- Rocky Linux 10

## Installation

```bash
ansible-galaxy collection install danylomikula.ansible_bootstrap
```

## Requirements

Ansible collections (install via `ansible-galaxy collection install -r requirements.yml`):
- `ansible.posix >= 1.5.0`
- `community.general >= 11.0.0`
- `community.crypto >= 2.0.0`

## First Run

On first run, when hosts don't have SSH keys configured yet:

```bash
# With password authentication
ansible-playbook -i inventory.ini site.yml --ask-pass --ask-become-pass

# Or shorter
ansible-playbook -i inventory.ini site.yml -k -K
```

After bootstrap completes, update inventory with SSH key paths:

```ini
[servers]
server01 ansible_host=10.20.0.50 ansible_ssh_private_key_file=./ssh_keys/server01_ed25519

[servers:vars]
ansible_user=admin
```

## Role Variables

### User Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `bootstrap_user_enabled` | `true` | Enable user creation |
| `bootstrap_user` | `"admin"` | Username to create |
| `bootstrap_user_password` | `""` | Hashed password (use `mkpasswd -m sha-512`) |
| `bootstrap_user_group` | `""` | Primary group (auto-detect: wheel/sudo) |
| `bootstrap_user_extra_groups` | `[]` | Additional groups |
| `bootstrap_user_nopasswd_sudo` | `true` | Allow passwordless sudo |

### SSH Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `bootstrap_ssh_enabled` | `true` | Enable SSH hardening |
| `bootstrap_ssh_port` | `22` | SSH port |
| `bootstrap_ssh_password_auth` | `false` | Allow password authentication |
| `bootstrap_ssh_root_login` | `false` | Allow root SSH login |
| `bootstrap_ssh_key_generate` | `false` | Generate SSH keypair locally |
| `bootstrap_ssh_key_local_dir` | `"./ssh_keys"` | Where to store generated keys |
| `bootstrap_ssh_key_type` | `"ed25519"` | Key type (ed25519, rsa, ecdsa) |
| `bootstrap_ssh_pubkey` | `""` | Path to existing public key |

### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `bootstrap_network_enabled` | `false` | Enable network configuration |
| `bootstrap_network_interface` | `""` | Interface name (auto-detect from active route if empty) |
| `bootstrap_network_connection` | `""` | NetworkManager connection name (RedHat only) |
| `bootstrap_static_ip` | `""` | Static IPv4 (e.g., "10.0.20.51/24") |
| `bootstrap_gateway` | `""` | IPv4 gateway |
| `bootstrap_dns4` | `["1.1.1.1", "1.0.0.1"]` | DNS servers |
| `bootstrap_dns4_ignore_auto` | `true` | Ignore DNS from DHCP |
| `bootstrap_static_ip6` | `""` | Static IPv6 address |
| `bootstrap_gateway6` | `""` | IPv6 gateway |
| `bootstrap_dns6` | `[]` | IPv6 DNS servers |
| `bootstrap_dns6_ignore_auto` | `true` | Ignore DNS from DHCPv6/SLAAC |
| `bootstrap_ipv6_dhcpv6` | `false` | Enable DHCPv6/SLAAC for public IPv6 |
| `bootstrap_ipv6_method` | `"auto"` | IPv6 method: auto (SLAAC), dhcp (DHCPv6), link-local |
| `bootstrap_ipv6_disabled` | `true` | Disable IPv6 completely |

### Firewall Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `bootstrap_firewall_enabled` | `false` | Enable firewall configuration |
| `bootstrap_firewall_zone` | `"public"` | Default firewalld zone |
| `bootstrap_firewall_services` | `["ssh"]` | Allowed services |
| `bootstrap_firewall_ports` | `[]` | Custom ports `[{port: 8080, proto: tcp}]` |
| `bootstrap_firewall_custom_zones` | `[]` | Custom zones with interfaces and ports (e.g., `[{ name: ftl, interface: lo, ports: [{ port: 4711, proto: tcp }] }]`) |
| `bootstrap_firewall_allow_icmp` | `true` | Allow ICMP ping |

### Other

| Variable | Default | Description |
|----------|---------|-------------|
| `bootstrap_hostname_enabled` | `true` | Set hostname |
| `bootstrap_hostname` | `"{{ inventory_hostname }}"` | Hostname to set |
| `bootstrap_expand_fs_enabled` | `false` | Expand root filesystem |
| `bootstrap_reboot_enabled` | `true` | Reboot after configuration |

## Example Playbook

### Using from Ansible Galaxy

```yaml
- name: Bootstrap servers
  hosts: all
  become: true
  vars:
    bootstrap_user: "admin"
    bootstrap_ssh_key_generate: true
    bootstrap_network_enabled: true
    bootstrap_dns4:
      - "1.1.1.1"
      - "1.0.0.1"
    bootstrap_dns6:
      - "2606:4700:4700::1111"
      - "2606:4700:4700::1001"
    bootstrap_ipv6_disabled: false
    bootstrap_ipv6_dhcpv6: true
    bootstrap_ipv6_method: "dhcp"
    bootstrap_firewall_enabled: true
    bootstrap_firewall_zone: "public"
    bootstrap_firewall_services:
      - ssh
      - http
      - https
      - dns
    bootstrap_firewall_custom_zones:
      - name: ftl
        interface: lo
        ports:
          - port: 4711
            proto: tcp
    bootstrap_firewall_allow_icmp: true
    bootstrap_expand_fs_enabled: true
  roles:
    - danylomikula.ansible_bootstrap.bootstrap
```

### Using from Source

```bash
ansible-playbook -i inventory.ini site.yml --ask-pass --ask-become-pass
```

## Example Inventory

```ini
[servers]
pihole-master ansible_host=10.20.160.250 bootstrap_static_ip=10.20.0.50/16 bootstrap_gateway=10.20.0.1 bootstrap_static_ip6=fda3:6tgc:b944:20::50/64 bootstrap_gateway6=fda3:6tgc:b944:20::1
pihole-backup ansible_host=10.20.200.38 bootstrap_static_ip=10.20.0.51/16 bootstrap_gateway=10.20.0.1 bootstrap_static_ip6=fda3:6tgc:b944:20::51/64 bootstrap_gateway6=fda3:6tgc:b944:20::1

[servers:vars]
ansible_user=ansible
```

## Custom Firewall Zones

```yaml
bootstrap_firewall_custom_zones:
  - name: ftl
    interface: lo
    ports:
      - port: 4711
        proto: tcp
```

## Testing

```bash
# Run full Hetzner Molecule matrix
HCLOUD_TOKEN=<token> ./scripts/test-all-platforms.sh

# Test specific scenario/platform
HCLOUD_TOKEN=<token> ./scripts/test-all-platforms.sh --scenario full --platform ubuntu2404

# Direct Molecule run (same as CI)
HCLOUD_TOKEN=<token> MOLECULE_HCLOUD_DISTRO=debian13 MOLECULE_HCLOUD_SCENARIO=full molecule test -s hetzner
```

## License

Apache 2.0 Licensed. See [LICENSE](../../LICENSE) for full details.

## Authors

Role managed by [Danylo Mikula](https://github.com/danylomikula).
