# 00: Prerequisites (manual)

## Goal

Get a fresh machine to a state where the LLM-driven setup can take over:

1. `~/nerdtools/` exists on the filesystem.
2. An LLM coding agent (Claude Code) is installed and authenticated.
3. Bare-minimum tools available: `git`, `curl`.

This section is **manual** — the LLM may not be installed yet. Run these commands yourself.

## Steps

### 0.1 Bootstrap tools

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
```

**macOS:** git and curl ship with Xcode Command Line Tools:
```bash
xcode-select -p >/dev/null 2>&1 || xcode-select --install
```

### 0.2 Get `~/nerdtools/`

Pick one option, NOT both.

**Option A — git clone** (single machine, or first machine in the sync):
```bash
git clone <YOUR_NERDTOOLS_REMOTE> ~/nerdtools
```

Replace `<YOUR_NERDTOOLS_REMOTE>` with the actual remote URL (e.g., `git@github.com:user/nerdtools.git`).

**Option B — Syncthing** (multi-machine sync, when one machine already has nerdtools):
1. Install Syncthing on both machines: https://syncthing.net/downloads/
2. On the source machine: share `~/nerdtools/` (mark as "Send Only" if you want one-way).
3. On the new machine: accept the share with target path `~/nerdtools/`.
4. Wait for full sync before moving on.

### 0.3 Install Claude Code

Follow the official install: https://docs.anthropic.com/claude-code

After install, authenticate:
```bash
claude  # opens, prompts for auth
```

### 0.4 Open Claude Code in nerdtools

```bash
cd ~/nerdtools
claude
```

Then prompt:
> *"Read setup/ and walk me through. Skip steps already done. Start from section 01."*

The LLM will take over from here.

## Skip rule

```bash
[[ -d ~/nerdtools/setup ]] && command -v git >/dev/null && command -v claude >/dev/null
```

## Verify

```bash
ls ~/nerdtools/setup/README.md
git --version
curl --version | head -1
command -v claude && claude --version
```

## Notes

- This file is "human-readable" — copy commands into your shell. Sections 01–06 are designed for LLM execution but also read fine as human docs.
- If you want to run setup fully manually (no LLM), each section's commands are runnable as-is. Just go in order.
- Section 00 has no LLM-driven version because the LLM bootstrap-paradox: the LLM can't install itself.
