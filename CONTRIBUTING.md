# Contributing to dotfailes_v2

Thank you for your interest in contributing to dotfailes_v2! This document provides guidelines for contributing to the project.

## Code of Conduct

Please be respectful and constructive in all interactions. We aim to foster an open and welcoming environment.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- A clear description of the problem
- Steps to reproduce the issue
- Expected vs. actual behavior
- Your operating system and shell version
- Any relevant error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please open an issue with:
- A clear description of the enhancement
- Use cases and benefits
- Any implementation ideas you have

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes on relevant platforms
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Guidelines

### Script Structure

All three scripts (bash, PowerShell, zsh) should maintain feature parity. When adding a new feature:

1. Implement it in all three scripts
2. Ensure consistent command syntax across platforms
3. Update documentation in all relevant files

### Code Style

**Bash/Zsh:**
- Use 4 spaces for indentation
- Follow Google Shell Style Guide
- Add comments for complex logic
- Use meaningful variable names
- Use `set -e` for error handling

**PowerShell:**
- Use 4 spaces for indentation
- Follow PowerShell style guide
- Use approved verbs for functions
- Add comment-based help for functions
- Handle errors appropriately

### Testing

Before submitting a PR, test your changes:

**Bash script:**
```bash
# Test on Linux
./dotfailes.sh help
./dotfailes.sh init /tmp/test-repo test-setup /tmp/test-home
./dotfailes.sh list
./dotfailes.sh status test-setup
```

**PowerShell script:**
```powershell
# Test on Windows/PowerShell
.\dotfailes.ps1 help
.\dotfailes.ps1 init C:\temp\test-repo test-setup C:\temp\test-home
.\dotfailes.ps1 list
.\dotfailes.ps1 status test-setup
```

**Zsh script:**
```zsh
# Test on MacOS
./dotfailes.zsh help
./dotfailes.zsh init /tmp/test-repo test-setup /tmp/test-home
./dotfailes.zsh list
./dotfailes.zsh status test-setup
```

### Documentation

When adding features, update:
- README.md (main documentation)
- EXAMPLES.md (practical examples)
- Help text in scripts

### Platform Support

Ensure compatibility with:
- **Bash**: Linux, Git Bash, MSYS2, WSL
- **Zsh**: MacOS, Linux (with zsh installed)
- **PowerShell**: Windows PowerShell 5.1+, PowerShell Core 6+

### Dependencies

Keep dependencies minimal:
- Bash/Zsh: Only `git` and `jq`
- PowerShell: Only `git`

If adding new dependencies, document them clearly.

## Project Structure

```
dotfailes_v2/
├── LICENSE              # GNU GPL v3.0
├── README.md            # Main documentation
├── EXAMPLES.md          # Usage examples
├── CONTRIBUTING.md      # This file
├── dotfailes.sh         # Bash script
├── dotfailes.zsh        # Zsh script
├── dotfailes.ps1        # PowerShell script
└── .gitignore          # Git ignore rules
```

## Feature Requests

Priority features for future development:
- [ ] Interactive setup wizard
- [ ] Automatic conflict resolution
- [ ] Template system for common dotfiles
- [ ] Integration with popular dotfile repositories
- [ ] Automated testing framework
- [ ] Installation script
- [ ] Homebrew formula
- [ ] Chocolatey package
- [ ] Debian/RPM packages

## Release Process

1. Update version numbers in scripts
2. Update CHANGELOG.md
3. Create a git tag
4. Create a GitHub release
5. Update documentation if needed

## Questions?

Feel free to open an issue for any questions about contributing!
