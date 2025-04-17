# Shell Script Review (Copilot Instructions Only)

Review the provided shell script using the rules below. Respond with thorough explanation and code blocks containing in-place corrections or additions with linenumbers. All suggestions must be immediately applicable in the editor.

## Best Practices

Ensure all scripts use:

- Strict mode: `set -euo pipefail`
- POSIX-compliant constructs
- Proper quoting and parameter handling
- Robust error management
- Common best practices

## Commenting & Documentation

- Add or correct file headers using `=` banners
- Use `---` dashed section headers
- Add concise function-level and inline comments
- Explain why the code does something, not just what it does

## Logging Standards

- Replace all `echo` calls with `bashio::log.*` (e.g. `log.info`, `log.error`)
- Ensure logs are appropriately leveled
- Insert logging where important execution events occur

## Code Refactoring

- Extract reusable logic into named functions
- Remove duplication
- Simplify nested conditionals
- Collapse multi-line pipelines where safe

## Logical Order

- Group related code logically:
  - Variable declarations
  - Dependency checks
  - Function definitions
  - Main logic
- Improve readability through consistent layout

## Enhancement Suggestions

Include high-level improvements, such as:

- Modularization opportunities
- Better dependency handling
- Interface improvements

## Performance Optimization

Identify and reduce performance bottlenecks:

- Minimize subprocess usage
- Avoid unnecessary I/O or re-evaluation

## Workflow Streamlining

Simplify complex logic and redundant conditionals.
Make the code path linear where possible.

## ShellCheck Compliance

Obey strict ShellCheck rules:

- Use `shellcheck -x -o all`
- Treat all warnings as errors
- Do not compromise functionality

## Function Sanity Test

Review logic flows and function interactions.
Check whether the code is likely to behave as intended under normal use.
