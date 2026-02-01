# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue or any other method with the repository owners before making a change.

## Pull Request Process

1. Update the README.md with details of changes to variables, features, or configuration options if applicable.
2. Run pre-commit hooks `pre-commit run -a`.
3. Ensure ansible-lint passes: `ansible-lint`.
4. Test your changes on all supported platforms (Debian 13, Ubuntu 24.04, Rocky Linux 10).
5. Once all outstanding comments and checklist items have been addressed, your contribution will be merged! Merged PRs will be included in the next release.

## Checklists for contributions

- [ ] Add [semantic prefix](#semantic-pull-requests) to your PR or Commits (at least one of your commit groups)
- [ ] CI tests are passing
- [ ] README.md has been updated after any changes to variables and features
- [ ] Run pre-commit hooks `pre-commit run -a`
- [ ] ansible-lint passes
- [ ] Tested on all supported platforms

## Semantic Pull Requests

To generate changelog, Pull Requests or Commits must have semantic prefix and follow conventional specs below:

- `feat:` for new features (minor version bump)
- `fix:` for bug fixes (patch version bump)
- `docs:` for documentation and examples
- `refactor:` for code refactoring
- `test:` for tests
- `ci:` for CI purpose
- `chore:` for chores stuff

The `chore` prefix is skipped during changelog generation. It can be used for `chore: update changelog` commit message by example.

## Development Setup

```bash
# Install Ansible dependencies
ansible-galaxy collection install -r requirements.yml

# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Install molecule for testing
pip install molecule molecule-plugins[docker]
```

## Testing

This project uses [Molecule](https://molecule.readthedocs.io/) for testing with Docker containers.

### Supported Platforms

- Debian 13
- Ubuntu 24.04
- Rocky Linux 10

### Test Scenarios

- `default` - Basic bootstrap with default settings
- `minimal` - Minimal configuration
- `ssh-generate` - SSH key generation testing
- `full` - Full configuration with all features enabled

### Running Tests

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

# Run molecule directly for a specific scenario
cd roles/bootstrap
molecule test -s default
```
