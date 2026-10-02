# Unit tests for treesitter parser resolution
# Imports the real nix/lib/treesitter.nix and nix/lib/data-loading.nix and
# verifies parser derivation, dependency expansion, user package handling,
# and extractLang behavior.
{ pkgs, testLib, ... }:

let
  inherit (pkgs) lib;

  # The real data loading library (provides extractLang)
  dataLib = import ../../nix/lib/data-loading.nix { inherit lib pkgs; };
  inherit (dataLib) extractLang;

  # Fixture treesitter mappings (shape of data/treesitter.json)
  fixtureTreesitterMappings = {
    core = [ "lua" "vim" "query" ];
    extras = {
      "lang.rust" = [ "rust" "ron" ];
      "lang.go" = [ "go" "gomod" ];
      "lang.typescript" = [ ]; # Extras may add no parsers
    };
  };

  # The real treesitter library under test
  tsLib = import ../../nix/lib/treesitter.nix {
    inherit lib pkgs;
    treesitterMappings = fixtureTreesitterMappings;
    inherit extractLang;
  };

  inherit (tsLib) automaticTreesitterParsers expandParserDependencies
    treesitterGrammars treesitterParsers toParserPlugin;

  baseCfg = {
    enable = true;
    treesitterParsers = [ ];
  };

  coreOnlyParsers = automaticTreesitterParsers baseCfg [ ];

  nixpkgsLua = pkgs.vimPlugins.nvim-treesitter-parsers.lua;

  # An out-of-tree grammar as users would build it (never actually built here)
  rawGrammar = language: pkgs.tree-sitter.buildGrammar {
    inherit language;
    version = "0.0.0";
    src = pkgs.emptyDirectory;
  };

in {
  # Core parsers are always included
  test-core-parsers-always-included = testLib.testEval
    "core-parsers-always-included"
    (builtins.all (p: builtins.elem p coreOnlyParsers) fixtureTreesitterMappings.core)
    true;

  # Enabled extras add their parsers
  test-enabled-extras-add-parsers = testLib.testEval
    "enabled-extras-add-parsers"
    (let parsers = automaticTreesitterParsers baseCfg [ "lang.rust" ];
     in builtins.elem "rust" parsers && builtins.elem "ron" parsers)
    true;

  # Extras that are not enabled contribute no parsers
  test-disabled-extras-no-parsers = testLib.testEval
    "disabled-extras-no-parsers"
    (builtins.elem "rust" coreOnlyParsers)
    false;

  # Extras with an empty parser list change nothing
  test-extras-no-additional-parsers = testLib.testEval
    "extras-no-additional-parsers"
    (automaticTreesitterParsers baseCfg [ "lang.typescript" ] == coreOnlyParsers)
    true;

  # Multiple enabled extras all contribute parsers
  test-multiple-extras-enabled = testLib.testEval
    "multiple-extras-enabled"
    (let parsers = automaticTreesitterParsers baseCfg [ "lang.rust" "lang.go" ];
     in builtins.all (p: builtins.elem p parsers) [ "rust" "ron" "go" "gomod" ])
    true;

  # Manual treesitterParsers packages are merged via extractLang
  test-manual-parsers-merged = testLib.testEval
    "manual-parsers-merged"
    (builtins.elem "wgsl" (automaticTreesitterParsers (baseCfg // {
      treesitterParsers = [ { grammarName = "wgsl"; } ];
    }) [ ]))
    true;

  # A manual parser already in core is deduplicated
  test-parser-deduplication = testLib.testEval
    "parser-deduplication"
    (builtins.length (lib.filter (p: p == "lua") (automaticTreesitterParsers (baseCfg // {
      treesitterParsers = [ { grammarName = "lua"; } ];
    }) [ ])))
    1;

  # With the module disabled, only manual parsers are derived
  test-disabled-module-only-manual-parsers = testLib.testEval
    "disabled-module-only-manual-parsers"
    (let parsers = automaticTreesitterParsers {
       enable = false;
       treesitterParsers = [ { grammarName = "wgsl"; } ];
     } [ "lang.rust" ];
     in builtins.elem "wgsl" parsers && !(builtins.elem "lua" parsers) && !(builtins.elem "rust" parsers))
    true;

  # expandParserDependencies: transitive requires from nixpkgs' grammar
  # metadata are pulled in (xml requires dtd)
  test-parser-dependency-closure-includes-transitive-requires = testLib.testEval
    "parser-dependency-closure-includes-transitive-requires"
    (builtins.elem "dtd" (expandParserDependencies [ "xml" ]))
    true;

  # expandParserDependencies: shared dependencies appear exactly once
  test-parser-dependency-closure-deduplicates-shared-deps = testLib.testEval
    "parser-dependency-closure-deduplicates-shared-deps"
    (builtins.length (lib.filter (p: p == "dtd") (expandParserDependencies [ "xml" "dtd" ])))
    1;

  # expandParserDependencies: query-only namespaces (html_tags) that are not
  # grammars are not pulled in
  test-parser-dependency-closure-skips-query-only-requires = testLib.testEval
    "parser-dependency-closure-skips-query-only-requires"
    (builtins.elem "html_tags" (expandParserDependencies [ "html" ]))
    false;

  # expandParserDependencies: languages unknown to nixpkgs (out-of-tree
  # grammars) are kept and simply have no dependencies
  test-parser-dependency-closure-keeps-unknown-languages = testLib.testEval
    "parser-dependency-closure-keeps-unknown-languages"
    (expandParserDependencies [ "haskell_literate" ])
    [ "haskell_literate" ];

  # treesitterGrammars: produces a parser derivation from nixpkgs grammars
  test-treesitter-grammars-is-derivation = testLib.testEval
    "treesitter-grammars-is-derivation"
    (lib.isDerivation (treesitterGrammars [ "lua" ]))
    true;

  # treesitterGrammars: a language nixpkgs does not ship fails with a clear
  # error instead of being silently dropped
  test-treesitter-grammars-missing-parser-throws = testLib.testEval
    "treesitter-grammars-missing-parser-throws"
    (builtins.tryEval (treesitterGrammars [ "definitely_missing_parser" ])).success
    false;

  # toParserPlugin: nixpkgs grammar plugins pass through untouched
  test-to-parser-plugin-passthrough = testLib.testEval
    "to-parser-plugin-passthrough"
    ((toParserPlugin nixpkgsLua).outPath == nixpkgsLua.outPath)
    true;

  # toParserPlugin: raw grammars are wrapped into parser/<language>.so plugins
  test-to-parser-plugin-wraps-raw-grammar = testLib.testEval
    "to-parser-plugin-wraps-raw-grammar"
    (let plugin = toParserPlugin (rawGrammar "haskell_literate");
     in lib.isDerivation plugin && plugin.grammarName == "haskell_literate")
    true;

  # treesitterParsers: user packages are installed alongside nixpkgs grammars
  test-treesitter-parsers-includes-user-packages = testLib.testEval
    "treesitter-parsers-includes-user-packages"
    (let
       cfg = baseCfg // { treesitterParsers = [ (rawGrammar "haskell_literate") ]; };
       drv = treesitterParsers cfg (automaticTreesitterParsers cfg [ ]);
       names = map (p: p.grammarName) drv.parsers;
     in builtins.elem "haskell_literate" names && builtins.elem "lua" names)
    true;

  # treesitterParsers: a user package overrides the nixpkgs grammar of the
  # same language instead of being installed next to it
  test-treesitter-parsers-user-package-overrides-nixpkgs = testLib.testEval
    "treesitter-parsers-user-package-overrides-nixpkgs"
    (let
       cfg = baseCfg // { treesitterParsers = [ (rawGrammar "lua") ]; };
       drv = treesitterParsers cfg [ "lua" ];
     in builtins.length drv.parsers == 1
        && (builtins.head drv.parsers).outPath != nixpkgsLua.outPath)
    true;

  # extractLang: grammarPlugins / nvim-treesitter-parsers style (grammarName)
  test-extract-lang-grammar-plugins = testLib.testEval
    "extract-lang-grammar-plugins"
    (map extractLang [
      { grammarName = "rust"; }
      { grammarName = "c_sharp"; }
      { grammarName = "json5"; }
    ] == [ "rust" "c_sharp" "json5" ])
    true;

  # extractLang: allGrammars style (language + passthru.associatedQuery)
  test-extract-lang-all-grammars = testLib.testEval
    "extract-lang-all-grammars"
    (map extractLang [
      { language = "ada"; pname = "tree-sitter-ada"; passthru.associatedQuery = { }; }
      { language = "markdown_inline"; pname = "tree-sitter-markdown_inline"; passthru.associatedQuery = { }; }
    ] == [ "ada" "markdown_inline" ])
    true;

  # extractLang: grammarName takes priority over language
  test-extract-lang-grammarname-priority = testLib.testEval
    "extract-lang-grammarname-priority"
    (extractLang { grammarName = "correct"; language = "wrong"; passthru.associatedQuery = { }; })
    "correct";

  # extractLang: raw grammars (buildGrammar output, tree-sitter-grammars.*)
  # are accepted by their language attribute
  test-extract-lang-raw-grammar = testLib.testEval
    "extract-lang-raw-grammar"
    (extractLang (rawGrammar "haskell_literate"))
    "haskell_literate";

  # extractLang: unknown package formats throw
  test-extract-lang-unknown-throws = testLib.testEval
    "extract-lang-unknown-throws"
    (builtins.tryEval (extractLang { name = "mystery-package"; })).success
    false;
}
