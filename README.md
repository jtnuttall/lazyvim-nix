# lazyvim-nix

A Nix flake for LazyVim that just works

## What is this?

This flake provides [LazyVim](https://www.lazyvim.org/) as a home-manager module, allowing you to install and configure LazyVim declaratively on NixOS. It tracks LazyVim releases and automatically updates plugin specifications within days of each release. By default, it pins plugin versions to match what a fresh LazyVim installation would get at release time, ensuring a consistent and reproducible configuration while keeping you current with upstream LazyVim.

## Quick Start

1. Add the flake to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    lazyvim.url = "github:pfassina/lazyvim-nix";
  };

  outputs = { nixpkgs, home-manager, lazyvim, ... }: {
    # Your system configuration
  };
}
```

2. Enable LazyVim in your home-manager configuration:

```nix
{
  imports = [ lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;
  };
}
```

3. That's it! Open `nvim` and enjoy LazyVim.

## Configuration

### Adding Language Support

```nix
programs.lazyvim = {
  enable = true;
  
  # Add LSP servers and tools
  extraPackages = with pkgs; [
    rust-analyzer
    gopls
    nodePackages.typescript-language-server
  ];
  
  # Add treesitter parsers
  treesitterParsers = with pkgs.tree-sitter-grammars; [
    tree-sitter-rust
    tree-sitter-go
    tree-sitter-typescript
    tree-sitter-tsx
  ];
};
```

### Customizing LazyVim

Configure LazyVim using the same directory structure as a standard LazyVim setup, but directly in your Nix configuration:

```nix
programs.lazyvim = {
  enable = true;

  # Maps to lua/config/ directory
  config = {
    # Custom autocmds → lua/config/autocmds.lua
    autocmds = ''
      vim.api.nvim_create_autocmd("FocusLost", {
        command = "silent! wa",
      })
    '';

    # Custom keymaps → lua/config/keymaps.lua
    keymaps = ''
      vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "Save file" })
    '';

    # Custom options → lua/config/options.lua
    options = ''
      vim.opt.relativenumber = false
      vim.opt.wrap = true
    '';
  };

  # Maps to lua/plugins/ directory
  plugins = {
    # Each key becomes lua/plugins/{key}.lua
    custom-theme = ''
      return {
        "folke/tokyonight.nvim",
        opts = { style = "night", transparent = true },
      }
    '';
    
    lsp-config = ''
      return {
        "neovim/nvim-lspconfig",
        opts = function(_, opts)
          opts.servers.rust_analyzer = {
            settings = {
              ["rust-analyzer"] = {
                checkOnSave = { command = "clippy" },
              },
            },
          }
          return opts
        end,
      }
    '';
  };
};
```

## How It Works

This flake:
- Tracks LazyVim releases automatically
- Pre-fetches all default LazyVim plugins through Nix
- Handles Nix-specific quirks (disables Mason.nvim, manages treesitter parsers)

## Differences from Regular LazyVim

- **No Mason.nvim**: LSP servers and tools are installed via `extraPackages`
- **Treesitter parsers**: Managed via `treesitterParsers` option
- **Plugins are pinned**: Plugin versions are fixed to match LazyVim's specifications
- **Plugin updates**: Happen through `nix flake update` instead of `:Lazy update`

## Plugin Management

### How Plugins Work

Plugins are pinned to specific versions that match LazyVim's specifications. You cannot manually update individual plugins - they are updated as a set when LazyVim releases new versions.

### Plugin Source Strategy

Configure where plugins are sourced from:

```nix
programs.lazyvim = {
  enable = true;

  # Default: "latest"
  pluginSource = "latest";  # or "nixpkgs"
};
```

**Options:**

- **`"latest"` (default)**: Ensures you get the latest plugin versions
  - For plugins where LazyVim specifies a version: uses that exact version
  - For plugins without specified versions: uses the latest release at the time of the last LazyVim update
  - Uses nixpkgs when it matches the required version, otherwise builds from source

- **`"nixpkgs"`**: Prioritizes stability and pre-built packages
  - Always uses nixpkgs versions when available
  - Only builds from source when LazyVim specifies a version not available in nixpkgs
  - Provides maximum stability by relying on tested nixpkgs packages

### Plugin Versioning

This flake captures plugin versions at the time of each LazyVim release:

1. **When LazyVim specifies a version** (rare): That exact version is used
2. **When no version is specified** (most plugins): The latest GitHub release/commit at update time is captured

This means:
- You get reproducible builds with consistent plugin versions
- Plugin versions are tied to LazyVim releases, not your system build time
- The `"latest"` strategy replicates a fresh LazyVim installation from that point in time
- **Note:** This may include bleeding-edge plugin versions that could have regressions

### Updating Plugins

```bash
# Update the flake inputs
nix flake update

# Rebuild your configuration
home-manager switch  # or nixos-rebuild switch
```

This gets you:
- Updated nixpkgs packages (if using `pluginSource = "nixpkgs"`)
- New plugin specifications when LazyVim releases a new version
- Latest plugin versions captured at the time of the LazyVim update

**Note:** Plugin versions are maintained in `plugins.json`, which is automatically updated by GitHub Actions when new LazyVim versions are released. Each update captures the latest plugin versions available at that time.

## Development

### Manual Updates

```bash
# Enter development shell
nix develop

# Update plugin list from LazyVim
./scripts/update-plugins.sh

# Update with nixpkgs verification (recommended)
./scripts/update-plugins.sh --verify

# Run tests
./test/test.sh
```

### Automated Updates

This flake includes GitHub workflows for automated maintenance:

1. **Daily Plugin Updates** (`update-plugins.yml`)
   - Runs daily at 2 AM UTC
   - Checks for new LazyVim releases
   - Creates PRs with plugin updates
   - Automatically adds verified plugin mappings

2. **On-Demand Mapping Updates** (`update-mappings.yml`)
   - Triggered manually via GitHub Actions
   - Or by commenting `/update-mappings` on a PR
   - Verifies and adds new plugin mappings

The workflows will:
- ✅ Verify new plugins exist in nixpkgs
- 🔄 Automatically add verified mappings
- 📋 Create PRs with detailed change summaries
- 🎯 Handle multi-module plugins correctly

## Acknowledgments

- [LazyVim](https://github.com/LazyVim/LazyVim) by [@folke](https://github.com/folke) - The amazing Neovim configuration framework that this flake packages
- This flake is heavily inspired by the setup from [@azuwis](https://github.com/azuwis). Thank you for the great foundation!

## License

MIT
