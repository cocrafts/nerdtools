# Ansible: deprecated

This directory is **deprecated** as of 2026-05-09. Do not run these playbooks.

## Replacement

See [`../setup/`](../setup/). The setup procedure is now expressed as markdown documents that an LLM (Claude Code or similar) reads and executes interactively.

## Why deprecate

- Personal/team dotfiles synced across 2–5 machines don't need Ansible's deterministic guarantees.
- Markdown is more flexible: "use latest mise" beats pinning a specific install command.
- LLM-driven setup adapts to changes (new tool versions, new install methods) without playbook updates.
- Less code to maintain. Setup procedure IS the documentation.

## Why kept (not deleted)

- Reference for what was previously installed.
- The `ansible/linux/templates/.ideavimrc` is still copied by `setup/05-symlinks.md` (TODO: migrate).
- Migration trail. Future-you may want to see the old YAML to understand a behavior.

## Differences captured in `setup/`

The new `setup/` reflects what we actually want today, not a verbatim translation:

| Old Ansible behavior                              | New `setup/` behavior                                 |
| ------------------------------------------------- | ----------------------------------------------------- |
| `cargo install mise` → `~/.cargo/bin/mise`        | `curl mise.run` → `~/.local/bin/mise`                 |
| `cargo install bat stylua starship taplo typos`   | `mise use -g bat@latest stylua@latest ...` (prebuilt) |
| `mise use go@1.22.2`                              | `go@latest`                                           |
| `mise use node@22.14.0` + npm globals             | `node@lts`, npm globals on demand                     |
| `zsh-nvm` plugin                                  | removed (Node via mise, not nvm)                      |
| Symlink `~/.claude` → `~/nerdtools/claude`        | removed (would destroy live Claude Code session data) |
| Haxe language server clone                        | removed (not needed)                                  |

These are decisions, not bugs in the old playbook.
