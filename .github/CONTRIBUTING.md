# Contributing to Technitium DNS Add-on

First off, thanks for taking the time to contribute! 🎉 👍

## Code of Conduct

This project and everyone participating in it are governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- Use a clear and descriptive title
- Describe the exact steps which reproduce the problem
- Provide specific examples to demonstrate the steps
- Describe the behavior you observed after following the steps
- Explain which behavior you expected to see instead and why
- Include screenshots if possible
- Include your Home Assistant and add-on version

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- Use a clear and descriptive title
- Provide a step-by-step description of the suggested enhancement
- Provide specific examples to demonstrate the steps
- Describe the current behavior and explain the behavior you expected to see
- Explain why this enhancement would be useful

### Pull Requests

- Fork the repo and create your branch from `main`
- Document new code based on the Documentation Styleguide
- Issue that pull request!

## Development Setup

1. Clone and setup:

   ```bash
   git clone https://github.com/staerk-ha-addons/addon-technitium-dns
   cd addon-technitium-dns
   code .
   ```

## Style Guides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

### Shell Script Style Guide

- Use shellcheck
- Use `set -euo pipefail`
- Document complex functions
- Use meaningful variable names

### YAML Style Guide

- Use 2 spaces for indentation
- Use snake_case for keys
- Document non-obvious options

### Documentation Style Guide

- Use [Markdown](https://www.markdownguide.org/)
- Reference section headers with anchor links
- Include code examples when relevant
- Keep line length to 80 characters

## Additional Notes

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
