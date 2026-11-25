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
- Performance settings: `GBARE_CACHE_TTL` (0 = off), `GBARE_CACHE_DIR`, `GBARE_JOBS`
- SSH helper: `_gbare_ssh()` builds connection with optional port
- Remote URL builder: `_gbare_remote_url()` handles port in URL
- Listing: `_gbare_repository_paths()` is the single enumeration point; it reads
  `_gbare_cache_read()` first and stores via `_gbare_cache_store()`. Call
  `_gbare_cache_invalidate()` after any change to the remote repository set.
- Batch commands: each command has a per-item worker (`_gbare_clone_one`,
  `_gbare_delete_one`, `_gbare_info_one`, `_gbare_backup_one`) driven by
  `_gbare_parallel <worker> <item>...`, which respects `GBARE_JOBS`/`-j` and
  replays buffered output in item order.

## Gotchas

- `status` is a read-only special variable in zsh; never name a local `status`.
  Use `rc` instead.
- `_gbare_validate_repo_name` returns 2 for a bad name, so callers must
  `|| return 1` rather than propagating the raw code as "existence unknown".

## CI

- GitHub Actions: `.github/workflows/test.yml` (unit tests), `opencode.yml` (opencode)
- OpenCode triggered by `/oc` or `/opencode` in comments
