# LazyVim Flake Plugin Version Mismatch Report

## Executive Summary

The lazyvim-nix flake is not providing LazyVim v15.x as expected, despite having updated `plugins.json` to track v15.5.0. The root cause is that the flake relies on nixpkgs' vimPlugins collection rather than building plugins from source when newer versions are available.

## Current Issue

### Expected Behavior
- `plugins.json` declares LazyVim v15.5.0 (commit 060e6dfaf7d4157b1a144df7d83179640dc52400)
- Users expect LazyVim 15.x features and functionality

### Actual Behavior
- System reports LazyVim v14.15.1 is installed
- The flake uses `pkgs.vimPlugins.LazyVim` which points to v14.15.0 from May 2025
- Nixpkgs unstable hasn't been updated with LazyVim 15.x yet

## Technical Analysis

### Current Implementation Flow

1. **Plugin Resolution** (`module.nix:126-134`)
   ```nix
   resolvedPlugins = map (pluginSpec:
     let
       nixName = resolvePluginName pluginSpec.name;
       plugin = pkgs.vimPlugins.${nixName} or null;
     in
       if plugin == null then
         builtins.trace "Warning: Could not find plugin ${pluginSpec.name}" null
       else
         plugin
   ) allPluginSpecs;
   ```

2. **Problem**: The flake always prefers nixpkgs versions without checking if they match the declared version in `plugins.json`

3. **Evidence**:
   - `/nix/store/fhzp91qibzva43zgssvz3scfd74cigdk-vimplugin-LazyVim-2025-05-12` contains v14.15.0
   - `plugins.json` declares v15.5.0 but this information is only used for metadata, not for fetching

### Impact
- Users cannot access LazyVim 15.x features despite the flake claiming support
- Breaking changes between v14 and v15 are not handled
- The flake's version tracking in `plugins.json` becomes misleading

## Proposed Solution

### Smart Plugin Resolution Strategy

Implement a two-tier plugin resolution system that:
1. Checks if the nixpkgs version matches the required version
2. Falls back to building from source when versions mismatch

### Implementation Approach

```nix
# Enhanced plugin resolver with version checking
resolvePluginWithVersion = pluginSpec:
  let
    nixName = resolvePluginName pluginSpec.name;
    nixpkgsPlugin = pkgs.vimPlugins.${nixName} or null;

    # Check version compatibility (pseudocode)
    isVersionCompatible =
      if nixpkgsPlugin != null && pluginSpec.commit != null then
        # Compare nixpkgs version with required commit/version
        checkVersionMatch nixpkgsPlugin pluginSpec
      else
        false;

    # Build from source if needed
    pluginFromSource = buildVimPlugin {
      pname = nixName;
      version = pluginSpec.version or "latest";
      src = fetchFromGitHub {
        owner = getOwner pluginSpec.name;
        repo = getRepo pluginSpec.name;
        rev = pluginSpec.commit;
        sha256 = pluginSpec.sha256; # Would need to be added to plugins.json
      };
    };
  in
    if nixpkgsPlugin != null && isVersionCompatible then
      nixpkgsPlugin  # Use nixpkgs version if it matches
    else
      pluginFromSource;  # Build from source for specific version
```

### Required Changes

1. **Enhance `plugins.json` generation**:
   - Add SHA256 hashes for each plugin
   - Include more detailed version information
   - Track nixpkgs compatibility status

2. **Update `module.nix`**:
   - Implement version checking logic
   - Add source building fallback
   - Create a `buildVimPlugin` helper function

3. **Add version comparison logic**:
   - Parse version strings from both sources
   - Implement compatibility checking
   - Handle edge cases (date-based versions, git commits, semantic versions)

4. **Update the update script**:
   - Fetch SHA256 hashes for all plugins
   - Check current nixpkgs versions
   - Generate compatibility metadata

## Benefits of This Approach

1. **Best of Both Worlds**:
   - Uses cached nixpkgs binaries when possible (faster builds)
   - Ensures correct versions when nixpkgs is outdated

2. **Transparency**:
   - Users get exactly the LazyVim version declared in `plugins.json`
   - Clear tracking of which plugins are built from source

3. **Maintainability**:
   - Automatic fallback reduces manual intervention
   - Update script handles version tracking

4. **Performance**:
   - Binary cache hits when versions match
   - Only builds from source when necessary

## Migration Path

1. **Phase 1**: Implement version checking for LazyVim core only
2. **Phase 2**: Extend to critical plugins (treesitter, LSP configs)
3. **Phase 3**: Apply to all tracked plugins
4. **Phase 4**: Add CI/CD to track nixpkgs updates and alert when versions converge

## Alternative Solutions Considered

### Option A: Always Build from Source
- **Pros**: Guaranteed correct versions
- **Cons**: Loses binary cache benefits, slower builds

### Option B: Fork/Override in Flake
- **Pros**: Simple implementation
- **Cons**: Maintenance burden, diverges from nixpkgs

### Option C: Wait for Nixpkgs Updates
- **Pros**: No changes needed
- **Cons**: Unpredictable delays, poor user experience

## Recommendation

Implement the **Smart Plugin Resolution Strategy** as it provides:
- Immediate access to latest LazyVim versions
- Graceful degradation to nixpkgs when appropriate
- Minimal performance impact for users
- Clear upgrade path as nixpkgs catches up

## Next Steps

1. Prototype the version checking logic
2. Update the plugin data structure to include SHA256 hashes
3. Test with LazyVim 15.x specifically
4. Extend to other frequently updated plugins
5. Document the new behavior for users

## Appendix: Current State Evidence

- **LazyVim in plugins.json**: v15.5.0 (2025-09-27)
- **LazyVim in nixpkgs**: v14.15.0 (2025-05-12)
- **Version Gap**: ~5 months, 1 major version
- **Affected Systems**: All users of lazyvim-nix flake

---

*Report generated: 2025-09-28*
*Issue discovered during investigation of LazyVim 15.x features not being available*