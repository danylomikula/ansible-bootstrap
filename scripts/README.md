# Scripts

Utility scripts for testing the bootstrap role.

## test-all-platforms.sh

Run molecule tests across all supported platforms and scenarios.

### Quick Start

```bash
# Run ALL scenarios on ALL platforms (12 tests total)
./scripts/test-all-platforms.sh

# Quick test - only default scenario on debian13
./scripts/test-all-platforms.sh --scenario default --platform debian13
```

### Usage

```bash
./scripts/test-all-platforms.sh [OPTIONS] [MOLECULE_COMMAND]
```

### Options

| Option | Description |
|--------|-------------|
| `--scenario NAME` | Run only specific scenario on all platforms |
| `--platform NAME` | Run all scenarios on specific platform only |
| `--list-scenarios` | List available scenarios |
| `--list-platforms` | List available platforms |
| `-h, --help` | Show help |

### Molecule Commands

Default command is `test`. You can specify any molecule command:

- `test` - Full test cycle (create, converge, verify, destroy)
- `converge` - Only create and configure (no destroy)
- `verify` - Only run verification tests
- `destroy` - Only destroy test instances

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STOP_ON_FAILURE` | `true` | Stop testing after first failure. Set to `false` to continue |
| `MOLECULE_DISTRO` | `debian13` | Override default distribution for single `molecule` runs |

### Supported Platforms

| Platform | Image |
|----------|-------|
| debian13 | geerlingguy/docker-debian13-ansible |
| ubuntu2404 | geerlingguy/docker-ubuntu2404-ansible |
| rockylinux10 | geerlingguy/docker-rockylinux10-ansible |

### Test Scenarios

| Scenario | Description | Features Tested |
|----------|-------------|-----------------|
| `default` | Standard configuration | User, SSH hardening, hostname, firewall |
| `minimal` | Minimal configuration | Only user creation (all else disabled) |
| `ssh-generate` | SSH key generation | Generate keypair locally, deploy to host |
| `full` | Full configuration | Custom groups, SSH port 2222, firewall ports |

### Examples

```bash
# Test all scenarios on all platforms
./scripts/test-all-platforms.sh

# Test only default scenario on debian13
./scripts/test-all-platforms.sh --scenario default --platform debian13

# Test all scenarios on Rocky Linux 10 only
./scripts/test-all-platforms.sh --platform rockylinux10

# Only converge (keep instances running for debugging)
./scripts/test-all-platforms.sh converge

# Continue testing after failures
STOP_ON_FAILURE=false ./scripts/test-all-platforms.sh

# List available scenarios
./scripts/test-all-platforms.sh --list-scenarios

# List available platforms
./scripts/test-all-platforms.sh --list-platforms
```

### Test Matrix

Running without filters executes: **4 scenarios x 3 platforms = 12 tests**

```
default/debian13       default/ubuntu2404       default/rockylinux10
minimal/debian13       minimal/ubuntu2404       minimal/rockylinux10
ssh-generate/debian13  ssh-generate/ubuntu2404  ssh-generate/rockylinux10
full/debian13          full/ubuntu2404          full/rockylinux10
```

### Output

The script provides colored output:
- `[INFO]` - Blue - General information
- `[PASS]` - Green - Test passed
- `[FAIL]` - Red - Test failed
- `[WARN]` - Yellow - Warnings
- `[SCENARIO]` - Cyan - Scenario start

At the end, a summary shows all test results with pass/fail counts.

### Requirements

- Docker (or Colima on macOS)
- Python 3.10+
- molecule
- molecule-plugins[docker]
- ansible-core

Install dependencies:

```bash
pip install molecule molecule-plugins[docker] ansible-core
ansible-galaxy collection install -r requirements.yml
```

### Notes

- **Network tests**: Disabled in Docker (static IP not applicable)
- **Expand filesystem**: Disabled in Docker (not applicable)
- **Reboot**: Disabled in Docker (would kill container)
