# Contributing to gbare

Thank you for your interest in contributing to gbare! This document provides guidelines and instructions for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/gbare.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run the tests
6. Commit and push your changes
7. Open a pull request

## Development

### Prerequisites

- zsh
- git
- SSH access to a server (for integration tests only)

### Project Structure

```
gbare/
├── gbare.zsh              # Main implementation
├── gbare.plugin.zsh       # Plugin entry point
├── man/
│   └── gbare.1            # Manual page
├── tests/
│   ├── lib/               # Test framework
│   ├── unit/              # Unit tests (no SSH required)
│   └── integration/       # Integration tests (requires SSH server)
└── README.md
```

### Running Tests

```bash
# Run all unit tests
./tests/run_tests.zsh

# Run a specific test file
zsh tests/unit/test_gbare.zsh
```

Unit tests run automatically in CI. Integration tests require an SSH server and should be run manually.

### Code Style

- Use zsh best practices
- Add function-level documentation comments for all public functions
- Include parameter descriptions, return values, and examples in comments
- Keep functions focused and single-purpose
- Use descriptive variable names

### Function Documentation Format

All functions should include documentation comments in the following format:

```zsh
# Brief description of what the function does
# Usage: function_name <arg1> [arg2]
# Args:
#   arg1 - Description (required)
#   arg2 - Description (optional)
# Returns:
#   Description of return value
# Example:
#   function_name "value"
my_function() {
  ...
}
```

## Pull Requests

1. Update documentation if you change functionality
2. Add tests for new features
3. Ensure all tests pass
4. Use clear, descriptive commit messages
5. Reference related issues in your PR description

## Commit Messages

Follow conventional commit style:

```
type: description

feat: add support for custom SSH key path
fix: handle empty port in remote URL
docs: update function documentation
test: add unit tests for clone function
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test changes
- `refactor`: Code refactoring
- `chore`: Maintenance tasks

## Issues

When opening an issue, please include:

- A clear description of the problem or feature request
- Steps to reproduce (for bugs)
- Expected behavior
- Actual behavior (for bugs)
- Environment information (OS, zsh version, etc.)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
