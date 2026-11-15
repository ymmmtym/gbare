# AGENTS.md

## Project

zsh plugin for managing bare Git repositories on remote servers. Modular code structure:
- `gbare.plugin.zsh` - Plugin entry point (sources all modules)
- `gbare.zsh` - Backward compatibility loader
- `lib/helpers.zsh` - Helper functions (SSH, URL builders)
- `lib/core.zsh` - Core functions (create, list, clone, delete, etc.)
- `lib/completion.zsh` - Zsh completion functions

## Commands

- Run all unit tests: `./tests/run_tests.zsh`
- Run single test file: `zsh tests/unit/test_gbare.zsh`
- CI runs unit tests only (integration tests require SSH server)

## Testing

- Custom test framework (`tests/lib/test_framework.zsh`), no external dependencies
- Unit tests: `tests/unit/` (no SSH required)
- Integration tests: `tests/integration/` (require SSH server, manual only)
- Test files: `tests/unit/test_*.zsh`

## Architecture

- Settings via env vars: `GBARE_USER`, `GBARE_HOST`, `GBARE_PORT`, `GBARE_PATH`
- SSH helper: `_gbare_ssh()` builds connection with optional port
- Remote URL builder: `_gbare_remote_url()` handles port in URL

## CI

- GitHub Actions: `.github/workflows/test.yml` (unit tests), `opencode.yml` (opencode)
- OpenCode triggered by `/oc` or `/opencode` in comments
