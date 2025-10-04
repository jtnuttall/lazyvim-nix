{ pkgs, pluginsJson }:

# Script to enrich plugins.json with nixpkgs version information
let
  lib = pkgs.lib;

  # Load plugin data from plugins.json
  pluginData = builtins.fromJSON (builtins.readFile pluginsJson);

  # Function to resolve plugin name to nixpkgs attribute
  resolvePluginName = pluginName:
    let
      # Load manual mappings
      mappings = import ../plugin-mappings.nix;

      # Check if there's a manual mapping
      manualMapping = mappings.${pluginName} or null;

      # If manual mapping exists and is a string, use it
      nixName = if builtins.isString manualMapping then
        manualMapping
      # If it's an attrset (multi-module), use the package name
      else if builtins.isAttrs manualMapping then
        manualMapping.package
      # Otherwise try automatic resolution
      else
        let
          # Extract repo name from "owner/repo" format
          parts = lib.splitString "/" pluginName;
          repoName = if builtins.length parts == 2 then
            builtins.elemAt parts 1
          else
            pluginName;

          # Convert repo-name to repo_name for nixpkgs naming convention
          underscored = builtins.replaceStrings ["-"] ["_"] repoName;

          # Remove common suffixes for cleaner matching
          cleaned = lib.removeSuffix "_nvim" (lib.removeSuffix "_vim" underscored);
        in
          # Try different naming patterns
          if pkgs.vimPlugins ? ${underscored} then underscored
          else if pkgs.vimPlugins ? ${cleaned} then cleaned
          else if pkgs.vimPlugins ? ${repoName} then repoName
          else null;
    in
      nixName;

  # Function to get nixpkgs version for a plugin
  getNixpkgsVersion = pluginSpec:
    let
      nixName = resolvePluginName pluginSpec.name;
      nixPlugin = if nixName != null then pkgs.vimPlugins.${nixName} or null else null;

      # Try to extract version from the nixpkgs plugin
      nixVersion = if nixPlugin != null then
        # Most plugins have .src.rev which contains the commit/tag
        nixPlugin.src.rev or
        # Some might have .version
        nixPlugin.version or
        # Fall back to checking if we can get it from the name
        (if nixPlugin ? src.name then
          # Extract version from name like "telescope.nvim-0.1.5"
          let
            nameMatch = builtins.match ".*-([0-9a-f]{40}|[0-9]+\\.[0-9]+.*)" nixPlugin.src.name;
          in
            if nameMatch != null then builtins.head nameMatch else null
        else null)
      else null;
    in
      nixVersion;

  # Enrich each plugin with nixpkgs version
  enrichedPlugins = map (plugin:
    plugin // {
      version_info = (plugin.version_info or {}) // {
        nixpkgs_version = getNixpkgsVersion plugin;
      };
    }
  ) pluginData.plugins;

  # Rebuild the complete JSON structure
  enrichedData = pluginData // {
    plugins = enrichedPlugins;
  };
in
  # Return as JSON string
  builtins.toJSON enrichedData