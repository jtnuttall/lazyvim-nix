# Basic regression tests that don't require complex tooling
{ pkgs, testLib, moduleUnderTest }:

{
  # Test that core files exist
  test-core-files-exist = testLib.runTest "core-files-exist" ''
    if [ -f "${../../flake.nix}" ] && [ -f "${../../module.nix}" ] && [ -f "${../../plugins.json}" ] && [ -f "${../../plugin-mappings.nix}" ]; then
      echo "Core files exist"
    else
      echo "Missing core files"
      exit 1
    fi
  '';

  # Test that plugins.json is valid JSON with required structure
  test-plugins-json-basic = testLib.runTest "plugins-json-basic" ''
    # Test JSON validity
    if ! jq . ${../../plugins.json} > /dev/null; then
      echo "plugins.json is not valid JSON"
      exit 1
    fi

    # Test has required top-level fields
    if ! jq -e 'has("version")' ${../../plugins.json} > /dev/null; then
      echo "Missing version field"
      exit 1
    fi

    if ! jq -e 'has("plugins")' ${../../plugins.json} > /dev/null; then
      echo "Missing plugins field"
      exit 1
    fi

    # Test plugins array is not empty
    plugin_count=$(jq '.plugins | length' ${../../plugins.json})
    if [ "$plugin_count" -le 0 ]; then
      echo "No plugins found"
      exit 1
    fi

    echo "plugins.json basic structure valid"
  '';

  # Test that core plugins are present
  test-core-plugins-basic = testLib.runTest "core-plugins-basic" ''
    # Test for LazyVim core plugin
    if ! jq -e '.plugins[] | select(.name == "LazyVim/LazyVim")' ${../../plugins.json} > /dev/null; then
      echo "LazyVim/LazyVim plugin not found"
      exit 1
    fi

    # Test for lazy.nvim
    if ! jq -e '.plugins[] | select(.name | contains("lazy"))' ${../../plugins.json} > /dev/null; then
      echo "lazy.nvim plugin not found"
      exit 1
    fi

    echo "Core plugins present"
  '';

  # Test that plugin mappings file is valid Nix
  test-plugin-mappings-valid = testLib.runTest "plugin-mappings-valid" ''
    # Test that the file exists
    if [ ! -f "${../../plugin-mappings.nix}" ]; then
      echo "plugin-mappings.nix not found"
      exit 1
    fi

    # Basic syntax check - file should start with { and end with }
    if ! head -1 ${../../plugin-mappings.nix} | grep -q '^{'; then
      echo "plugin-mappings.nix doesn't start with {"
      exit 1
    fi

    if ! tail -1 ${../../plugin-mappings.nix} | grep -q '}'; then
      echo "plugin-mappings.nix doesn't end with }"
      exit 1
    fi

    echo "Plugin mappings file valid"
  '';

  # Test plugin count doesn't regress dramatically
  test-plugin-count-reasonable = testLib.runTest "plugin-count-reasonable" ''
    plugin_count=$(jq '.plugins | length' ${../../plugins.json})
    echo "Plugin count: $plugin_count"

    # We expect at least 20 plugins in a basic LazyVim setup
    if [ "$plugin_count" -lt 20 ]; then
      echo "Plugin count too low: $plugin_count (expected >= 20)"
      exit 1
    fi

    echo "Plugin count reasonable"
  '';

  # Test that extraction metadata is present
  test-extraction-metadata-present = testLib.runTest "extraction-metadata-present" ''
    # Check extraction report has required fields
    if ! jq -e '.extraction_report | has("total_plugins")' ${../../plugins.json} > /dev/null; then
      echo "Missing total_plugins field"
      exit 1
    fi

    if ! jq -e '.extraction_report | has("mapped_plugins")' ${../../plugins.json} > /dev/null; then
      echo "Missing mapped_plugins field"
      exit 1
    fi

    # Check counts are reasonable
    total_plugins=$(jq '.extraction_report.total_plugins' ${../../plugins.json})
    actual_plugins=$(jq '.plugins | length' ${../../plugins.json})

    if [ "$total_plugins" != "$actual_plugins" ]; then
      echo "Plugin count mismatch: reported $total_plugins, actual $actual_plugins"
      exit 1
    fi

    echo "Extraction metadata present and consistent"
  '';
}