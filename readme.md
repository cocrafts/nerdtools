# NerdTools

A unified development environment for Metacraft developers that automates configuration across macOS and Linux systems.

## Quick Start

### macOS Setup

1. Install prerequisites:
   ```bash
   # Install Homebrew
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Install Ansible
   brew install ansible
   
   # Install Starship (optional)
   brew install starship
   ```

2. Deploy environment:
   ```bash
   # Clone repository to home directory
   git clone <repo-url> ~/nerdtools
   
   # Run Ansible playbook
   cd ~/nerdtools
   ansible-playbook -i hosts.yml macos.yml
   ```

### Linux Setup

1. Configure hosts:
   - Edit `hosts.yml` with your target IP address
   - Ensure SSH access is configured to the target machine
   - Verify Ansible is installed on the remote client

2. Deploy environment:
   ```bash
   ansible-playbook -i hosts.yml linux.yml
   
   # Set Zsh as default shell
   chsh -s $(which zsh)
   ```

## Neovim Configuration

### Required Dependencies

| Tool | Installation | Purpose |
|------|-------------|---------|
| LLVM | `brew install llvm --with-toolchain` | C/C++ toolchain |
| Ruff | `pip3 install ruff` | Python linter |
| MyPy | `pip3 install mypy` | Python type checker |
| JSON Language Server | `pip3 install jsonls` | JSON support |
| Pyright | `pip3 install pyright` | Python LSP |
| Codespell | `pip3 install codespell` | Spell checker |
| ASCII Image Converter | [Link](https://github.com/TheZoraiz/ascii-image-converter) | Image display |

### Manual LSP Installations

These LSPs should be installed manually rather than via Mason:

| LSP | Installation | Language |
|-----|-------------|----------|
| WGSL Analyzer | [Link](https://github.com/wgsl-analyzer/wgsl-analyzer) | WebGPU Shading |
| Hurl | [Link](https://hurl.dev/docs/installation.html) | API testing |
| Lua Language Server | `brew install lua-language-server` | Lua |
| Rust Analyzer | `rustup component add rust-src` | Rust |
| Gopls | [Link](https://github.com/golang/tools/tree/master/gopls) | Go |
| ZLS | [Link](https://github.com/zigtools/zls) | Zig |
| NPH | [Link](https://github.com/arnetheduck/nph) | Nim formatter |
| SwiftLint & SwiftFormat | `brew install swiftlint swiftformat` | Swift |

## Terminal Configuration

- **Kitty**: Use `kitty +kitten ssh` instead of `ssh` when connecting to Linux systems
- **Wezterm**: [Configure undercurl](https://wezfurlong.org/wezterm/faq.html?h=undercurl#how-do-i-enable-undercurl-curly-underlines) for proper styling
- **Mise**: Use for [cross-language version management](https://mise.jdx.dev/lang/bun.html)

## Recommended Tools

- [btop](https://github.com/aristocratos/btop) - Resource monitor with modern UI

