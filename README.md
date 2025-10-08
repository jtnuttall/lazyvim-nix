# lazyvim-nix

A bleeding edge Nix flake for [LazyVim](https://www.lazyvim.org/) for NixOS and home-manager users.

## Quick Start

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

```nix
{
  imports = [ lazyvim.homeManagerModules.default ];

  programs.lazyvim.enable = true;
}
```

That's it! Open `nvim` and enjoy LazyVim.

## Complete Configuration Example

Here's every available option with explanations:

```nix
{
  imports = [ lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;

    # Plugin source strategy:
    # - "latest" (default): Uses exact versions from LazyVim specifications
    # - "nixpkgs": Prioritizes nixpkgs versions for stability
    pluginSource = "latest";

    # LazyVim extras - enable by category and name
    extras = {
      # Language support
      lang = {
        nix = {
          enable = true;
          # Optional: Override default configuration
          config = ''
            "stevearc/conform.nvim",
            opts = {
              formatters_by_ft = {
                nix = { "alejandra" }
              }
            }
          '';
        };
        python.enable = true;
      };

      editor = {
        telescope.enable = true;
        neo-tree.enable = true;
      };
    };

    # LSP servers, formatters, and tools (installed via Nix)
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nixd
      rust-analyzer

      # Formatters
      alejandra
      stylua

      # Tools
      ripgrep
      fd
    ];

    # Treesitter parsers (managed by Nix, not auto-installed)
    treesitterParsers = with pkgs.tree-sitter-grammars; [
      tree-sitter-bash
      tree-sitter-lua
    ];

    # LazyVim configuration files (maps to lua/config/)
    config = {
      # lua/config/options.lua
      options = ''
        vim.opt.relativenumber = false
        vim.opt.wrap = true
      '';

      # lua/config/keymaps.lua
      keymaps = ''
        vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "Save" })
      '';

      # lua/config/autocmds.lua
      autocmds = ''
        vim.api.nvim_create_autocmd("FocusLost", {
          command = "silent! wa",
        })
      '';
    };

    # Plugin configurations (maps to lua/plugins/)
    plugins = {
      # Each key creates lua/plugins/{key}.lua
      colorscheme = ''
        return {
          "folke/tokyonight.nvim",
          opts = {
            style = "night",
            transparent = true,
          },
        }
      '';
    };
  };
}
```

## Configuration Guide

### Starting Simple

The minimal configuration just enables LazyVim:

```nix
programs.lazyvim.enable = true;
```

### Adding Language Support

Use LazyVim extras for comprehensive language support:

```nix
programs.lazyvim = {
  enable = true;

  extras = {
    lang.nix.enable = true;
    lang.python.enable = true;
  };

  # IMPORTANT: Extras don't install treesitter parsers automatically
  # You must add them manually for syntax highlighting
  treesitterParsers = with pkgs.tree-sitter-grammars; [
    tree-sitter-nix
    tree-sitter-python
  ];
};
```

**Note**: LazyVim extras configure language features (LSP, formatters, etc.) but **do not** install treesitter parsers. You must add parsers manually via `treesitterParsers` to get syntax highlighting.

### Installing Tools and LSP Servers

Since Mason.nvim is disabled, install tools through Nix:

```nix
programs.lazyvim = {
  enable = true;

  extraPackages = with pkgs; [
    # LSP servers
    nixd
    pyright

    # Formatters
    black
    alejandra

    # Tools
    ripgrep
    fd
  ];
};
```

### Managing Treesitter Parsers

Treesitter parsers are managed through Nix instead of auto-installing:

```nix
programs.lazyvim = {
  enable = true;

  treesitterParsers = with pkgs.tree-sitter-grammars; [
    tree-sitter-bash
    tree-sitter-lua
    tree-sitter-python
  ];
};
```

### Customizing LazyVim Settings

Add your own Vim options, keymaps, and autocmds:

```nix
programs.lazyvim = {
  enable = true;

  config = {
    options = ''
      vim.opt.relativenumber = false
      vim.opt.wrap = true
    '';

    keymaps = ''
      vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
    '';
  };
};
```

### Adding and Configuring Plugins

Add custom plugins or override existing ones:

```nix
programs.lazyvim = {
  enable = true;

  plugins = {
    # Add a new plugin
    my-theme = ''
      return {
        "catppuccin/nvim",
        name = "catppuccin",
        opts = { flavour = "mocha" },
      }
    '';

    # Override existing plugin configuration
    telescope = ''
      return {
        "nvim-telescope/telescope.nvim",
        opts = {
          defaults = {
            layout_strategy = "horizontal",
          },
        },
      }
    '';
  };
};
```

### Customizing LazyVim Extras

Override default configurations for extras:

```nix
programs.lazyvim = {
  enable = true;

  extras = {
    lang.rust = {
      enable = true;
      config = ''
        opts = {
          servers = {
            rust_analyzer = {
              settings = {
                ["rust-analyzer"] = {
                  cargo = {
                    features = "all",
                  },
                },
              },
            },
          },
        }
      '';
    };
  };
};
```

### Plugin Source Strategy

Control where plugins are sourced from:

```nix
programs.lazyvim = {
  enable = true;

  # "latest": Latest versions at LazyVim release time (default)
  # "nixpkgs": Prefer nixpkgs versions
  pluginSource = "nixpkgs";
};
```

## Available LazyVim Extras

### Categories

- **ai**: AI coding assistants (copilot, codeium, supermaven)
- **coding**: Editing enhancements (yanky, luasnip, mini-surround)
- **dap**: Debug adapter protocol support
- **editor**: Editor features (telescope, fzf, neo-tree, aerial)
- **formatting**: Code formatters (prettier, black)
- **lang**: Language support (50+ languages including nix, rust, python, go)
- **linting**: Linters (eslint)
- **lsp**: LSP tools (none-ls, neoconf)
- **test**: Testing frameworks
- **ui**: UI enhancements (alpha, dashboard, mini-animate)
- **util**: Utilities (chezmoi, gitui)

## How It Works

This flake:
1. **Tracks LazyVim releases** - Automatically updates when LazyVim releases
2. **Manages plugins through Nix** - All plugins are pre-fetched, no runtime downloads
3. **Disables Mason.nvim** - LSP servers and tools come from Nix packages
4. **Handles Nix quirks** - Treesitter parsers managed declaratively
5. **Pins plugin versions** - Reproducible builds with consistent versions

### Differences from Regular LazyVim

| Regular LazyVim | lazyvim-nix |
|-----------------|-------------|
| Mason.nvim installs tools | Tools via `extraPackages` |
| Auto-installs treesitter parsers | Parsers via `treesitterParsers` |
| `:Lazy update` updates plugins | `nix flake update` updates plugins |
| Plugin versions float | Versions pinned to LazyVim releases |

## Updating

```bash
# Update the flake (gets new LazyVim version if available)
nix flake update

# Rebuild your configuration
home-manager switch  # or nixos-rebuild switch
```

## Development

```bash
# Enter development shell
nix develop

# Update plugin specifications from LazyVim
./scripts/update-plugins.sh

# Run tests
./test/test.sh
```

### Automated Updates

This flake includes GitHub workflows that:
- Check for new LazyVim releases daily
- Update plugin specifications automatically
- Create PRs with detailed changelogs

## Acknowledgments

- [LazyVim](https://github.com/LazyVim/LazyVim) by [@folke](https://github.com/folke)
- Inspired by [@azuwis](https://github.com/azuwis)'s Nix setup

## License

MIT
