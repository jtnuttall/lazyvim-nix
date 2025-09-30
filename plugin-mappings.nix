# Mappings from LazyVim plugin names to nixpkgs vimPlugins names
# This file handles the cases where automatic name resolution fails
#
# Automatic resolution converts plugin names as follows:
#   1. Takes the repository name (after the /)
#   2. Replaces hyphens (-) with underscores (_)
#   3. Replaces dots (.) with hyphens (-)
#
# Examples of automatic resolution:
#   "owner/plugin.nvim" -> "plugin-nvim"
#   "owner/plugin-name" -> "plugin_name"
#   "owner/plugin-name.nvim" -> "plugin_name-nvim"
#
# Multi-module plugin support:
# Some plugins (like mini.nvim) provide multiple modules from a single package.
# LazyVim treats each module as a separate plugin, but they all come from the same
# nixpkgs package. Use this format for multi-module plugins:
#
#   "owner/plugin.module" = { package = "nixpkgs-name"; module = "module-name"; };
#
# This creates a symlink from "module-name" to "nixpkgs-name" in the dev path,
# allowing LazyVim to find each module individually while using the same Nix package.

{
  # Mini.nvim modules (multi-module plugin: single package with multiple modules)
  # LazyVim 15.x uses nvim-mini organization (renamed from echasnovski)
  "nvim-mini/mini.ai" = { package = "mini-nvim"; module = "mini.ai"; };
  "nvim-mini/mini.bufremove" = { package = "mini-nvim"; module = "mini.bufremove"; };
  "nvim-mini/mini.comment" = { package = "mini-nvim"; module = "mini.comment"; };
  "nvim-mini/mini.icons" = { package = "mini-nvim"; module = "mini.icons"; };
  "nvim-mini/mini.indentscope" = { package = "mini-nvim"; module = "mini.indentscope"; };
  "nvim-mini/mini.pairs" = { package = "mini-nvim"; module = "mini.pairs"; };
  "nvim-mini/mini.surround" = { package = "mini-nvim"; module = "mini.surround"; };

  # Legacy mini.nvim references (LazyVim extras still use these)
  "echasnovski/mini.icons" = { package = "mini-nvim"; module = "mini.icons"; };

  # Plugins that don't follow standard naming conventions
  "L3MON4D3/LuaSnip" = "luasnip";
  "catppuccin/nvim" = "catppuccin-nvim";
  "folke/ts-comments.nvim" = "ts-comments-nvim";
  "MagicDuck/grug-far.nvim" = "grug-far-nvim";
  "nvim-neo-tree/neo-tree.nvim" = "neo-tree-nvim";
  "nvim-lualine/lualine.nvim" = "lualine-nvim";
  "akinsho/bufferline.nvim" = "bufferline-nvim";
  "folke/noice.nvim" = "noice-nvim";
  "MunifTanjim/nui.nvim" = "nui-nvim";
  "rcarriga/nvim-notify" = "nvim-notify";
  
  # Plugins with uppercase letters that need special handling
  "RRethy/vim-illuminate" = "vim-illuminate";
  "JoosepAlviste/nvim-ts-context-commentstring" = "nvim-ts-context-commentstring";
  
  # LazyVim core
  "LazyVim/LazyVim" = "LazyVim";
  
  # Plugins where automatic hyphen-to-underscore conversion doesn't match nixpkgs
  "folke/todo-comments.nvim" = "todo-comments-nvim";
  "folke/which-key.nvim" = "which-key-nvim";
  "lukas-reineke/indent-blankline.nvim" = "indent-blankline-nvim";
  "nvim-telescope/telescope-fzf-native.nvim" = "telescope-fzf-native-nvim";
  "nvim-tree/nvim-web-devicons" = "nvim-web-devicons";
  "simrat39/rust-tools.nvim" = "rust-tools-nvim";
  "akinsho/flutter-tools.nvim" = "flutter-tools-nvim";
  "jose-elias-alvarez/typescript.nvim" = "typescript-nvim";
  "smjonas/inc-rename.nvim" = "inc-rename-nvim";
  "jay-babu/mason-nvim-dap.nvim" = "mason-nvim-dap";
  "stevearc/conform.nvim" = "conform-nvim";
  "mason-org/mason.nvim" = "mason-nvim";
  "mason-org/mason-lspconfig.nvim" = "mason-lspconfig-nvim";
  
  # Folke's plugins
  "folke/lazy.nvim" = "lazy-nvim";
  "folke/lazydev.nvim" = "lazydev-nvim";
  "folke/tokyonight.nvim" = "tokyonight-nvim";
  "folke/flash.nvim" = "flash-nvim";
  "folke/trouble.nvim" = "trouble-nvim";
  "folke/persistence.nvim" = "persistence-nvim";
  
  # Snacks.nvim - Important: use the exact name LazyVim expects
  "folke/snacks.nvim" = "snacks-nvim";
  
  # Git plugins
  "lewis6991/gitsigns.nvim" = "gitsigns-nvim";
  
  # Standard vim plugin names
  "dstein64/vim-startuptime" = "vim-startuptime";
  
  # Treesitter ecosystem
  "nvim-treesitter/nvim-treesitter" = "nvim-treesitter";
  "nvim-treesitter/nvim-treesitter-textobjects" = "nvim-treesitter-textobjects";
  "nvim-treesitter/nvim-treesitter-context" = "nvim-treesitter-context";
  "windwp/nvim-ts-autotag" = "nvim-ts-autotag";
  
  # LSP and completion
  "neovim/nvim-lspconfig" = "nvim-lspconfig";
  "hrsh7th/nvim-cmp" = "nvim-cmp";
  "hrsh7th/cmp-nvim-lsp" = "cmp-nvim-lsp";
  "hrsh7th/cmp-buffer" = "cmp-buffer";
  "hrsh7th/cmp-path" = "cmp-path";
  "rafamadriz/friendly-snippets" = "friendly-snippets";
  
  # DAP (Debug Adapter Protocol)
  "mfussenegger/nvim-dap" = "nvim-dap";
  "rcarriga/nvim-dap-ui" = "nvim-dap-ui";
  "theHamsta/nvim-dap-virtual-text" = "nvim-dap-virtual-text";
  
  # UI plugins
  "nvimdev/dashboard-nvim" = "dashboard-nvim";
  "goolord/alpha-nvim" = "alpha-nvim";
  
  # Testing
  "nvim-neotest/neotest-go" = "neotest-go";
  "nvim-neotest/neotest-python" = "neotest-python";
  "nvim-neotest/neotest-plenary" = "neotest-plenary";
  "nvim-neotest/neotest-vim-test" = "neotest-vim-test";
  
  # Blink completion  
  "saghen/blink.cmp" = "blink-cmp";
  
  # FZF integration
  "ibhagwan/fzf-lua" = "fzf-lua";
  
  # LazyGit
  "kdheepak/lazygit.nvim" = "lazygit-nvim";
  
  
  # Neoconf and Neodev
  "folke/neoconf.nvim" = "neoconf-nvim";
  "folke/neodev.nvim" = "neodev-nvim";
  
  # Core dependencies
  "nvim-lua/plenary.nvim" = "plenary-nvim";
  
  # Miscellaneous
  "kevinhwang91/nvim-ufo" = "nvim-ufo";
  "kevinhwang91/promise-async" = "promise-async";
  "windwp/nvim-autopairs" = "nvim-autopairs";
  "mfussenegger/nvim-lint" = "nvim-lint";
}