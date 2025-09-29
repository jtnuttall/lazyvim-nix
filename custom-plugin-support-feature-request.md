# Feature Request: Support for User-Defined Custom Plugins

## Summary

The lazyvim-nix flake currently only processes plugins from the predefined `plugins.json` file (LazyVim's core plugins), but does not handle custom plugins that users define in their LazyVim configuration files. This creates a significant limitation where custom plugins are forced to use potentially outdated nixpkgs versions instead of being built from the latest source.

## Current Issue

### Problem Description
When users add custom plugins to their LazyVim configuration (e.g., in `plugins/colorscheme.lua`), these plugins are not processed by the flake's smart version resolution system. Instead, they fall back to whatever version exists in nixpkgs, which may be outdated or missing features.

### Real-World Example
A user added the `aktersnurra/no-clown-fiesta.nvim` colorscheme plugin:

```lua
-- plugins/colorscheme.lua
return {
  { "aktersnurra/no-clown-fiesta.nvim" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "no-clown-fiesta",
    },
  },
}
```

**Result**: The plugin fails to load with this error:
```
module 'lua.lualine.themes.no-clown-fiesta-low-contrast' not found
```

**Root Cause**:
- nixpkgs has `no-clown-fiesta.nvim` from January 2025
- The latest upstream version (September 26, 2025) includes the missing lualine theme
- The flake doesn't process custom plugins, so it uses the outdated nixpkgs version

## Current Architecture Limitation

The flake's plugin resolution logic in `module.nix:170-200` only processes plugins from `plugins.json`:

```nix
# This only works for plugins in plugins.json
allPluginSpecs = pluginData.plugins or [];

# User-defined plugins in config files are ignored
resolvedPlugins = map (pluginSpec:
  let nixName = resolvePluginName pluginSpec.name;
  # ... only processes predefined specs
) allPluginSpecs;
```

## Proposed Solution

### Option 1: Plugin Scanning (Recommended)
Add functionality to scan user's LazyVim configuration files for plugin specifications and include them in the resolution process.

**Implementation**:
1. Parse `plugins/*.lua` files to extract plugin specifications
2. Add discovered plugins to the resolution pipeline
3. Apply the same version checking logic (prefer latest source over outdated nixpkgs)

**Benefits**:
- Automatic detection of user plugins
- No additional configuration required
- Consistent behavior for all plugins

### Option 2: Manual Plugin Override
Add a module option for users to specify custom plugins with version information.

**Implementation**:
```nix
programs.lazyvim = {
  enable = true;
  customPlugins = {
    "aktersnurra/no-clown-fiesta.nvim" = {
      owner = "aktersnurra";
      repo = "no-clown-fiesta.nvim";
      rev = "18b537a5cb473ac50dadf4abc45b943bc31cddfc";
      sha256 = "...";
    };
  };
};
```

**Benefits**:
- Explicit control over plugin versions
- Can specify exact commits/versions

**Drawbacks**:
- Requires manual configuration
- Duplicates plugin definitions

### Option 3: Hybrid Approach
Combine both approaches: automatic scanning with manual override capability.

## Technical Implementation Notes

### Plugin Detection
For Option 1, the flake would need to:

1. **Parse Lua files**: Extract plugin specs from `return { { "owner/repo" }, ... }` patterns
2. **Handle various formats**:
   ```lua
   { "owner/repo" }
   { "owner/repo", branch = "main" }
   { "owner/repo", commit = "abc123" }
   ```
3. **Resolve conflicts**: Handle cases where both auto-detected and manual specs exist

### Version Resolution Enhancement
Extend the existing resolution logic to include user-defined plugins:

```nix
# Enhanced plugin collection
allPluginSpecs = (pluginData.plugins or []) ++ (discoverUserPlugins cfg.configPath);

# Apply same smart resolution to all plugins
resolvedPlugins = map resolvePlugin allPluginSpecs;
```

## Expected Benefits

1. **Consistent Plugin Management**: All plugins (core and custom) get the same smart version resolution
2. **Latest Features**: Users get access to latest plugin features automatically
3. **Reduced Friction**: No manual intervention needed for custom plugins
4. **Better Error Handling**: Avoid issues with missing features in outdated nixpkgs versions

## Use Cases

- **Colorschemes**: Users often use custom colorschemes not in LazyVim defaults
- **Language-specific plugins**: Plugins for specific programming languages or frameworks
- **Personal workflows**: Custom plugins for individual developer needs
- **Preview plugins**: Testing new plugins before they become mainstream

## Compatibility Considerations

- Should maintain backward compatibility with existing configurations
- Consider performance impact of file parsing
- Handle edge cases (malformed Lua, complex plugin specs)
- Graceful fallback for parsing failures

## Alternative Workarounds (Current)

Users currently must:
1. Fork the lazyvim-nix repository
2. Manually add plugins to `plugins.json`
3. Use outdated nixpkgs versions
4. Override plugins in their home-manager configuration

These workarounds are suboptimal and create maintenance burden.

## Conclusion

Supporting user-defined custom plugins would significantly improve the lazyvim-nix flake's usability and completeness. The automatic scanning approach (Option 1) would provide the best user experience while maintaining the flake's core philosophy of smart plugin version management.

This feature request addresses a fundamental gap in the current architecture and would make the flake more robust for real-world LazyVim usage patterns.

---

**Environment**:
- lazyvim-nix flake commit: [current commit]
- NixOS 25.11
- LazyVim 15.5.0 (successfully upgraded via recent flake improvements)
- Affected plugin: `aktersnurra/no-clown-fiesta.nvim`

**Priority**: Medium-High (affects user adoption and daily usage)