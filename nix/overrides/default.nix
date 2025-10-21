# Nix-specific overrides for LazyVim plugins
# Only dependency-focused overrides - let LazyVim handle plugin behavior

{ pkgs }:

{
  # Telescope needs ripgrep and fd for file searching
  "telescope.nvim" = {
    dependencies = with pkgs; [ ripgrep fd ];
  };

  # Neo-tree needs system utilities for file operations
  "neo-tree.nvim" = {
    dependencies = with pkgs; [
      coreutils
      findutils
    ];
  };

  # Noice.nvim needs terminal utilities
  "noice.nvim" = {
    dependencies = with pkgs; [ ncurses ];
  };

  # Mason is completely disabled in Nix (essential for Nix compatibility)
  "mason.nvim" = {
    enabled = false;
  };

  "mason-lspconfig.nvim" = {
    enabled = false;
  };

  "mason-nvim-dap.nvim" = {
    enabled = false;
  };

  # Git-related plugins need git in PATH
  "gitsigns.nvim" = {
    dependencies = with pkgs; [ git ];
  };

  "diffview.nvim" = {
    dependencies = with pkgs; [ git ];
  };

  "neogit" = {
    dependencies = with pkgs; [ git ];
  };

  "lazygit.nvim" = {
    dependencies = with pkgs; [ lazygit ];
  };

  # Toggleterm needs shell utilities
  "toggleterm.nvim" = {
    dependencies = with pkgs; [
      bash
      coreutils
    ];
  };
}