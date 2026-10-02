# Treesitter management utilities for LazyVim Nix module
#
# Parsers come from nixpkgs' nvim-treesitter grammar set
# (pkgs.vimPlugins.nvim-treesitter.grammarPlugins). Their revisions therefore
# follow the consumer's nixpkgs pin (and `inputs.nixpkgs.follows`), and the
# nvim-treesitter plugin + queries are taken from the same nixpkgs package
# (see plugin-resolution.nix), so parsers and queries always come from one
# nvim-treesitter revision.
#
# Any package that ships a compiled grammar can be added through
# `programs.lazyvim.treesitterParsers`. It is installed as-is and takes
# precedence over the nixpkgs grammar of the same language, which is how you
# pin a single parser or bring in an out-of-tree grammar.
{
  lib,
  pkgs,
  treesitterMappings,
  extractLang,
}:

let
  grammarPlugins = pkgs.vimPlugins.nvim-treesitter.grammarPlugins or { };

  hasGrammar = parserName: builtins.hasAttr parserName grammarPlugins;

  # nixpkgs records each grammar's buildable dependencies (e.g. xml -> dtd)
  # in passthru.requires. Query-only namespaces such as html_tags or ecma are
  # not grammars and never appear there, so no extra filtering is needed
  # beyond "is this a grammar we can install".
  parserRequires =
    parserName: lib.filter hasGrammar ((grammarPlugins.${parserName} or { }).requires or [ ]);

  expandParserDependencies =
    parserNames:
    let
      go =
        seen: pending:
        if pending == [ ] then
          seen
        else
          let
            parserName = builtins.head pending;
            rest = builtins.tail pending;
          in
          if builtins.elem parserName seen then
            go seen rest
          else
            go (seen ++ [ parserName ]) (rest ++ parserRequires parserName);
    in
    go [ ] parserNames;

  # Normalize a user-supplied package into the vim-plugin layout nvim expects
  # on the runtimepath: parser/<language>.so.
  #   - pkgs.vimPlugins.nvim-treesitter-parsers.* / grammarPlugins.*: already
  #     in that layout, used verbatim
  #   - raw grammars (pkgs.tree-sitter.buildGrammar output,
  #     nvim-treesitter.allGrammars.*, pkgs.tree-sitter-grammars.*): $out/parser
  #     is the shared object itself, so it is linked into place
  toParserPlugin =
    pkg:
    let
      language = extractLang pkg;
    in
    if pkg ? grammarName then
      pkg
    else
      pkgs.runCommand "treesitter-grammar-${language}"
        {
          passthru = {
            grammarName = language;
            grammar = pkg;
          };
        }
        ''
          mkdir -p $out/parser
          if [ -f ${pkg}/parser ]; then
            ln -s ${pkg}/parser $out/parser/${language}.so
          elif [ -f ${pkg}/parser/${language}.so ]; then
            ln -s ${pkg}/parser/${language}.so $out/parser/${language}.so
          else
            echo "treesitter parser package for '${language}' (${pkg}) ships neither parser nor parser/${language}.so" >&2
            exit 1
          fi
        '';

  # nixpkgs grammar packages for a list of parser names. Fails loudly (and
  # eagerly: callers seq the result) when a
  # requested language is not in nixpkgs, instead of silently dropping it.
  nixpkgsGrammars =
    parserNames:
    let
      missing = lib.filter (parserName: !(hasGrammar parserName)) parserNames;
    in
    if missing != [ ] then
      throw ''
        lazyvim-nix could not find the following treesitter parsers in
        pkgs.vimPlugins.nvim-treesitter.grammarPlugins:
          ${lib.concatStringsSep ", " missing}

        Parsers are taken from nixpkgs so they follow your nixpkgs pin. Either
        update nixpkgs, or provide the grammar yourself through
        programs.lazyvim.treesitterParsers: any package that ships a compiled
        parser (for example the output of pkgs.tree-sitter.buildGrammar) is
        accepted and installed as-is.
      ''
    else
      map (parserName: grammarPlugins.${parserName}) parserNames;

in
{
  # Derive the list of parser language names to install:
  # core parsers + parsers of enabled extras + user packages, closed over
  # nixpkgs' requires metadata.
  automaticTreesitterParsers =
    cfg: enabledExtraNames:
    if cfg.enable then
      let
        # Core parsers are always included
        coreParsers = treesitterMappings.core or [ ];

        # Extra parsers based on enabled extras
        extraParsers = lib.flatten (
          map (extraName: treesitterMappings.extras.${extraName} or [ ]) enabledExtraNames
        );

        requestedParsers = lib.unique (
          coreParsers ++ extraParsers ++ (map extractLang cfg.treesitterParsers)
        );
      in
      expandParserDependencies requestedParsers
    else
      expandParserDependencies (map extractLang cfg.treesitterParsers);

  # nixpkgs grammars only, for a list of parser names.
  treesitterGrammars =
    parserNames:
    let
      parsers = nixpkgsGrammars parserNames;
    in
    builtins.seq parsers (pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = parsers;
      passthru = { inherit parsers; };
    });

  # The full parser set the module installs: the user's packages verbatim,
  # plus nixpkgs grammars for every other requested language.
  treesitterParsers =
    cfg: parserNames:
    let
      userParsers = map toParserPlugin cfg.treesitterParsers;
      userLanguages = map (parser: parser.grammarName) userParsers;
      remaining = lib.filter (parserName: !(builtins.elem parserName userLanguages)) parserNames;
      parsers = nixpkgsGrammars remaining ++ userParsers;
    in
    builtins.seq parsers (pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = parsers;
      passthru = { inherit parsers; };
    });

  inherit expandParserDependencies toParserPlugin;
}
