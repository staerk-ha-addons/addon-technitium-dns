# GitHub Copilot Custom Instructions (AI-Only)

These instructions are exclusively for GitHub Copilot. All guidance below is intended to optimize AI-generated code and commentary for this project.

- Provide comprehensive guidance and best practices in code generation.
- Include comments that clearly explain the functionality and purpose of code blocks.
- Reference related suggestions with line numbers where applicable.
- Output only in code block format, ready to be used in the editor.
- Use Markdown formatting where appropriate in documentation or generated content.

## Project Context

- Home Assistant Add-on: Technitium DNS Server built on HA Community Add-on best practices.
- Base image: `ghcr.io/hassio-addons/debian-base` (Debian Slim w/ s6-overlay v3, Bashio, Tempio, jq, curl).

## Shell Scripting Standards

- Use `#!/command/with-contenv bashio`.
- Enable strict mode: `set -o nounset -o errexit -o pipefail`.
- Use `bashio::log.*` and `bashio::exit.nok`.
- All enviroment variabels are to be set in "technitium-dns/rootfs/etc/s6-overlay/s6-rc.d/init-env/run" with the write_env function.
- Follow strict ShellCheck requirements and treat all warnings as errors.; Ignore SC1091,SC2154; Always obey the following:
  - SC2310: This function is invoked in an 'if' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.
  - SC2312: Consider invoking this command separately to avoid masking its return value (or use '|| true' to ignore).
  - SC2250: Prefer putting braces around variable references even when not strictly required.
  - SC2248: Prefer double quoting even when variables don't contain special characters.
  - SC2206: Quote to prevent word splitting/globbing, or split robustly with mapfile or read -a.
- All comments must be on ther own line; no comments on same line as code.
- Follow a comprehensive, hierarchical comment style:
  - Use dashed-line dividers for major section headers.
  - Document functions concisely immediately above declarations.
  - Prefix all log messages with the module name for traceability.
  - Focus comments on explaining functionality, not repeating code.
  - Clearly separate conceptual context from implementation details.

## Linting Standards

Copilot must ensure all generated code conforms to the following linting tools and practices. All warnings must be treated as errors unless explicitly documented and justified.

Code should be written to avoid common linting issues:

- Always quote shell variables to prevent globbing and word splitting.
- Use consistent indentation and formatting (e.g., no trailing whitespace).
- Avoid unnecessary complexity and favor readability.

### JSONLint

Always format JSON using `jsonlint --strict --no-duplicate-keys`.

### ShellCheck

Validate shell scripts with `shellcheck -x -o all` and resolve all warnings.

### YAMLLint

Ensure YAML files pass `yamllint -c .yamllint.yml --strict`. Use 2-space indentation consistently.

### Hadolint

Dockerfiles must be compliant with `hadolint` guidelines.
