# Scripts

Utility scripts for testing the bootstrap role.

## test-all-platforms.sh

Run Molecule Hetzner scenarios across distro/scenario matrix.

### Quick Start

```bash
# Run compact Hetzner matrix (8 curated jobs)
HCLOUD_TOKEN=<token> ./scripts/test-all-platforms.sh

# Run one scenario on one distro
HCLOUD_TOKEN=<token> ./scripts/test-all-platforms.sh --scenario network --platform ubuntu2404
```

### Usage

```bash
HCLOUD_TOKEN=<token> ./scripts/test-all-platforms.sh [OPTIONS] [MOLECULE_COMMAND]
```

### Options

| Option | Description |
|--------|-------------|
| `--scenario NAME` | Run only specific scenario on all distros |
| `--platform NAME` | Run all scenarios on specific distro |
| `--list-scenarios` | List available scenarios |
| `--list-platforms` | List available distros |
| `-h, --help` | Show help |

### Molecule Commands

Default command is `test`. You can pass any Molecule command:

- `test` - Full cycle (create, converge, verify, destroy)
- `converge` - Provision and apply role only
- `verify` - Run verifier only
- `destroy` - Destroy allocated test resources

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HCLOUD_TOKEN` | required | Hetzner Cloud API token |
| `HCLOUD_SERVER_TYPE` | `cx33` | Hetzner server type |
| `HCLOUD_LOCATION` | `hel1` | Primary Hetzner location |
| `HCLOUD_FALLBACK_LOCATIONS` | `fsn1,nbg1` | Extra locations when primary has no capacity |
| `STOP_ON_FAILURE` | `true` | Stop after first failed matrix item |

### Supported Distros

| Distro | Hetzner image |
|--------|---------------|
| `debian13` | `debian-13` |
| `ubuntu2404` | `ubuntu-24.04` |
| `rockylinux10` | `rocky-10` |

### Scenarios

| Scenario | Description |
|----------|-------------|
| `minimal` | Minimal user setup only |
| `full` | Extended user/SSH/firewall setup (includes SSH key generation checks) |
| `network` | NetworkManager + firewall validation (Debian/Ubuntu) |
| `expand-fs` | Filesystem expansion checks |
| `reboot` | Reboot flow validation |

### Notes

- Default matrix combinations:
  - `full`: `debian13`, `ubuntu2404`, `rockylinux10`
  - `network`: `debian13`, `ubuntu2404`
  - `minimal`: `debian13`
  - `expand-fs`: `ubuntu2404`
  - `reboot`: `ubuntu2404`
- CI uses the same Molecule `hetzner` scenario as this script.
- Workflow-level cleanup removes leaked `mol-<run_id>-*` resources when needed.
