# Data loading utilities for LazyVim Nix module
{ lib, pkgs }:

{
  # Load plugin data and mappings
  pluginData = pkgs.lazyvimPluginData or (builtins.fromJSON (builtins.readFile ../../data/plugins.json));
  pluginMappings = pkgs.lazyvimPluginMappings or (builtins.fromJSON (builtins.readFile ../../data/mappings.json));

  # Load extras metadata
  extrasMetadata = pkgs.lazyvimExtrasMetadata or (builtins.fromJSON (builtins.readFile ../../data/extras.json));

  # Load treesitter parser mappings
  treesitterMappings = pkgs.lazyvimTreesitterMappings or (builtins.fromJSON (builtins.readFile ../../data/treesitter.json));

  # Load consolidated dependencies
  dependencies = pkgs.lazyvimDependencies or (builtins.fromJSON (builtins.readFile ../../data/dependencies.json));

  # Load LazyVim starter configuration (raw lua content and version)
  starterLua = builtins.readFile ../../data/starter-lazy.lua;
  starterVersion = lib.trim (builtins.readFile ../../data/starter-version.txt);

  # Helper to extract language name from treesitter parser packages
  # Supports:
  #   - pkgs.vimPlugins.nvim-treesitter.grammarPlugins.* (has grammarName)
  #   - pkgs.vimPlugins.nvim-treesitter-parsers.* (alias for above)
  #   - pkgs.vimPlugins.nvim-treesitter.allGrammars (has language + passthru.associatedQuery)
  #   - pkgs.tree-sitter.buildGrammar output / pkgs.tree-sitter-grammars.* (has language)
  extractLang = pkg:
    let
      grammarName = pkg.grammarName or null;
      language = pkg.language or null;
      pname = pkg.pname or "";
      name = pkg.name or "";
      # nvim-treesitter grammars have associatedQuery in passthru
      hasAssociatedQuery = (pkg.passthru or {}) ? associatedQuery;
    in
      # Prefer grammarName (from grammarPlugins / nvim-treesitter-parsers)
      if grammarName != null then grammarName
      # Accept language only if it's from nvim-treesitter (has associatedQuery)
      else if language != null && hasAssociatedQuery then language
      # Raw grammars: pkgs.tree-sitter.buildGrammar output, pkgs.tree-sitter-grammars.*
      # (installed as-is by nix/lib/treesitter.nix, so queries are the user's job)
      else if language != null then language
      # Unknown package format
      else
        throw ''
          Unknown treesitter package format: ${name}

          treesitterParsers expects packages from:
            - pkgs.vimPlugins.nvim-treesitter-parsers.* (recommended)
            - pkgs.vimPlugins.nvim-treesitter.grammarPlugins.*
            - pkgs.vimPlugins.nvim-treesitter.allGrammars

          Example:
            treesitterParsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [ lua nix rust go ];
        '';
}