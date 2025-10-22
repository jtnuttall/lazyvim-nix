# Treesitter management utilities for LazyVim Nix module
{ lib, pkgs, treesitterMappings, extractLang }:

{
  # Derive automatic treesitter parsers
  automaticTreesitterParsers = cfg: enabledExtras:
    if cfg.enable then
      let
        # Get enabled extra names in "category.name" format for lookup
        enabledExtraNames = lib.flatten (lib.mapAttrsToList (category: extras:
          lib.mapAttrsToList (name: extraConfig:
            lib.optional (extraConfig.enable or false) "${category}.${name}"
          ) extras
        ) (cfg.extras or {}));

        # Core parsers are always included
        coreParsers = treesitterMappings.core or [];

        # Extra parsers based on enabled extras
        extraParsers = lib.flatten (map (extraName:
          treesitterMappings.extras.${extraName} or []
        ) enabledExtraNames);

        # Combine and deduplicate all parsers (keep as names, not packages)
        allParsers = lib.unique (coreParsers ++ extraParsers ++ (map extractLang cfg.treesitterParsers));
      in
        allParsers
    else
      map extractLang cfg.treesitterParsers;

  # Generate Lua array string for parser list
  treesitterLangList = automaticTreesitterParsers:
    lib.concatStringsSep ", " (map (l: ''"${l}"'') automaticTreesitterParsers);

  # Treesitter configuration - use nvim-treesitter's grammar plugins directly
  treesitterGrammars = automaticTreesitterParsers:
    let
      # automaticTreesitterParsers now contains parser names, not packages
      parserNames = automaticTreesitterParsers;

      # Use nvim-treesitter's grammar plugins which are compatible
      parserPackages = lib.filter (pkg: pkg != null) (map (parserName:
        pkgs.vimPlugins.nvim-treesitter.grammarPlugins.${parserName} or (
          builtins.trace "Warning: treesitter parser '${parserName}' not found in nvim-treesitter grammar plugins" null
        )
      ) parserNames);

      parsers = pkgs.symlinkJoin {
        name = "treesitter-parsers";
        paths = parserPackages;
      };
    in parsers;
}