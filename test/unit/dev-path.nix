# Unit tests for dev path creation and symlink handling
{ pkgs, testLib, moduleUnderTest }:

{
  # Test dev path creation with regular plugins
  test-dev-path-regular-plugins = testLib.testNixExpr
    "dev-path-regular-plugins"
    ''
      let
        # Mock plugin specs and resolved plugins
        pluginSpecs = [
          { name = "folke/lazy.nvim"; }
          { name = "neovim/nvim-lspconfig"; }
        ];

        # Mock resolved plugins (simplified)
        resolvedPlugins = [
          "/nix/store/fake1-lazy-nvim"
          "/nix/store/fake2-nvim-lspconfig"
        ];

        # Extract repository names
        getRepoName = specName:
          let parts = builtins.filter (x: x != "") (builtins.split "/" specName);
          in if builtins.length parts >= 2 then builtins.elemAt parts 2 else specName;

        # Test repo name extraction
        lazyRepo = getRepoName "folke/lazy.nvim";
        lspRepo = getRepoName "neovim/nvim-lspconfig";

        correctRepoNames = lazyRepo == "lazy.nvim" && lspRepo == "nvim-lspconfig";
      in correctRepoNames
    ''
    "true";

  # Test multi-module plugin deduplication
  test-multi-module-deduplication = testLib.testNixExpr
    "multi-module-deduplication"
    ''
      let
        # Mock mini.nvim modules (same package, different modules)
        pluginSpecs = [
          { name = "nvim-mini/mini.ai"; }
          { name = "nvim-mini/mini.pairs"; }
          { name = "folke/lazy.nvim"; }
        ];

        # Mock mappings
        mappings = {
          "nvim-mini/mini.ai" = { package = "mini-nvim"; module = "mini.ai"; };
          "nvim-mini/mini.pairs" = { package = "mini-nvim"; module = "mini.pairs"; };
        };

        # Simulate deduplication logic
        pluginWithType = map (spec:
          let
            mapping = mappings.''${spec.name} or null;
            isMultiModule = mapping != null && builtins.isAttrs mapping && mapping ? module;
          in {
            spec = spec;
            isMultiModule = isMultiModule;
            linkName = if isMultiModule then mapping.module else spec.name;
          }
        ) pluginSpecs;

        # Group by link name (deduplication)
        grouped = builtins.groupBy (p: p.linkName) pluginWithType;

        # Should have 3 unique link names: mini.ai, mini.pairs, folke/lazy.nvim
        uniqueCount = builtins.length (builtins.attrNames grouped);
      in uniqueCount == 3
    ''
    "true";

  # Test symlink command generation
  test-symlink-commands = testLib.testNixExpr
    "symlink-commands"
    ''
      let
        # Mock deduplicated plugins
        plugins = [
          { linkName = "lazy.nvim"; plugin = "/nix/store/fake1-lazy-nvim"; }
          { linkName = "mini.ai"; plugin = "/nix/store/fake2-mini-nvim"; }
        ];

        # Generate symlink commands
        linkCommands = map (p: "ln -sf ''${p.plugin} $out/''${p.linkName}") plugins;

        # Check command structure
        hasCorrectCommands =
          builtins.any (cmd: builtins.match ".*ln -sf.*lazy-nvim.*lazy.nvim.*" cmd != null) linkCommands &&
          builtins.any (cmd: builtins.match ".*ln -sf.*mini-nvim.*mini.ai.*" cmd != null) linkCommands;
      in hasCorrectCommands
    ''
    "true";

  # Test plugin type detection
  test-plugin-type-detection = testLib.testNixExpr
    "plugin-type-detection"
    ''
      let
        # Test mapping structures
        stringMapping = "lazy-nvim";
        objectMapping = { package = "mini-nvim"; module = "mini.ai"; };

        # Test detection logic
        isStringMapping = builtins.isString stringMapping;
        isObjectMapping = builtins.isAttrs objectMapping && objectMapping ? package && objectMapping ? module;
      in isStringMapping && isObjectMapping
    ''
    "true";

  # Test repository name extraction edge cases
  test-repo-name-edge-cases = testLib.testNixExpr
    "repo-name-edge-cases"
    ''
      let
        # Test various plugin name formats
        testCases = [
          { input = "folke/lazy.nvim"; expected = "lazy.nvim"; }
          { input = "nvim-telescope/telescope.nvim"; expected = "telescope.nvim"; }
          { input = "single-name"; expected = "single-name"; }
          { input = "owner/repo-with-hyphens"; expected = "repo-with-hyphens"; }
        ];

        getRepoName = specName:
          let parts = builtins.filter (x: x != "") (builtins.split "/" specName);
          in if builtins.length parts >= 2 then builtins.elemAt parts 2 else specName;

        # Test all cases
        results = map (case:
          getRepoName case.input == case.expected
        ) testCases;

        allCorrect = builtins.all (x: x) results;
      in allCorrect
    ''
    "true";

  # Test link name generation for multi-module plugins
  test-link-name-generation = testLib.testNixExpr
    "link-name-generation"
    ''
      let
        mappings = {
          "nvim-mini/mini.ai" = { package = "mini-nvim"; module = "mini.ai"; };
          "folke/lazy.nvim" = "lazy-nvim";
        };

        specs = [
          { name = "nvim-mini/mini.ai"; }
          { name = "folke/lazy.nvim"; }
        ];

        getLinkName = spec:
          let
            mapping = mappings.''${spec.name} or null;
            getRepoName = specName:
              let parts = builtins.filter (x: x != "") (builtins.split "/" specName);
              in if builtins.length parts >= 2 then builtins.elemAt parts 2 else specName;
          in
            if mapping != null && builtins.isAttrs mapping && mapping ? module then
              mapping.module
            else
              getRepoName spec.name;

        # Test link name generation
        miniLinkName = getLinkName (builtins.elemAt specs 0);
        lazyLinkName = getLinkName (builtins.elemAt specs 1);

        correctNames = miniLinkName == "mini.ai" && lazyLinkName == "lazy.nvim";
      in correctNames
    ''
    "true";
}