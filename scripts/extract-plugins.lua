-- Enhanced LazyVim Plugin Extractor with Two-Pass Processing
-- This uses a minimal LazyVim setup to get the plugin list and provides mapping suggestions

-- Load mapping suggestion engine
local suggest_mappings = require('suggest-mappings')

-- Load user plugin scanner
local user_scanner = require('scan-user-plugins')

-- Function to parse plugin-mappings.nix
local function parse_plugin_mappings(mappings_file)
  local mappings = {}
  local multi_module_mappings = {}
  
  local file = io.open(mappings_file, "r")
  if not file then
    print("Warning: Could not open plugin-mappings.nix, proceeding without existing mappings")
    return mappings, multi_module_mappings
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Parse standard mappings: "plugin/name" = "nixpkgs-name";
  for plugin_name, nixpkgs_name in content:gmatch('"([^"]+)"[%s]*=[%s]*"([^"]+)";') do
    mappings[plugin_name] = nixpkgs_name
  end
  
  -- Parse multi-module mappings: "plugin/name" = { package = "pkg"; module = "mod"; };
  for plugin_name, package, module in content:gmatch('"([^"]+)"[%s]*=[%s]*{[%s]*package[%s]*=[%s]*"([^"]+)";[%s]*module[%s]*=[%s]*"([^"]+)";[%s]*};') do
    multi_module_mappings[plugin_name] = {
      package = package,
      module = module
    }
  end
  
  print(string.format("Loaded %d standard mappings and %d multi-module mappings", 
                      table.maxn and table.maxn(mappings) or #mappings,
                      table.maxn and table.maxn(multi_module_mappings) or #multi_module_mappings))
  
  return mappings, multi_module_mappings
end

function ExtractLazyVimPlugins(lazyvim_path, output_file, version, commit)
  -- Set up paths
  vim.opt.runtimepath:prepend(lazyvim_path)
  
  -- Mock some globals that LazyVim might expect
  _G.LazyVim = {}
  
  -- Parse existing plugin mappings
  local mappings_file = "plugin-mappings.nix"
  local existing_mappings, multi_module_mappings = parse_plugin_mappings(mappings_file)
  
  -- Load LazyVim's plugin specifications directly
  local plugins = {}
  local seen = {}
  local unmapped_plugins = {}
  local extraction_report = {
    total_plugins = 0,
    mapped_plugins = 0,
    unmapped_plugins = 0,
    multi_module_plugins = 0,
    mapping_suggestions = {}
  }
  
  -- Known mappings from short names to full names
  local short_to_full = {
    ["mason.nvim"] = "mason-org/mason.nvim",
    ["gitsigns.nvim"] = "lewis6991/gitsigns.nvim", 
    ["snacks.nvim"] = "folke/snacks.nvim",
  }
  
  -- Function to normalize plugin names
  local function normalize_name(name)
    if type(name) ~= "string" then return nil end
    
    -- If it's already in owner/repo format, return as-is
    if name:match("^[%w%-]+/[%w%-%._]+$") then
      return name
    end
    
    -- Check if it's a known short name
    return short_to_full[name]
  end
  
  -- Function to normalize dependencies
  local function normalize_deps(deps)
    if not deps then return {} end
    
    local normalized = {}
    if type(deps) == "string" then
      local norm = normalize_name(deps)
      if norm then table.insert(normalized, norm) end
    elseif type(deps) == "table" then
      for _, dep in ipairs(deps) do
        if type(dep) == "string" then
          local norm = normalize_name(dep) or dep
          table.insert(normalized, norm)
        elseif type(dep) == "table" and dep[1] then
          local norm = normalize_name(dep[1]) or dep[1]
          table.insert(normalized, norm)
        end
      end
    end
    return normalized
  end
  
  -- Function to check if a plugin is mapped
  local function is_plugin_mapped(plugin_name)
    -- Check if it's in existing mappings or multi-module mappings
    return existing_mappings[plugin_name] ~= nil or multi_module_mappings[plugin_name] ~= nil
  end
  
  -- Function to collect plugin specs recursively
  local function collect_plugin(spec)
    if type(spec) == "string" then
      local normalized = normalize_name(spec)
      -- Only add if it's in owner/repo format
      if normalized and not seen[normalized] then
        seen[normalized] = true
        
        -- Extract repository info
        local owner, repo = normalized:match("^([^/]+)/(.+)$")

        local plugin_info = {
          name = normalized,
          owner = owner,
          repo = repo,
          dependencies = {},
          source_file = "string_spec",
          -- Placeholder for version info to be filled later
          version_info = {
            commit = nil,
            tag = nil,
            sha256 = nil
          }
        }
        
        -- Add multi-module info if applicable
        if multi_module_mappings[normalized] then
          plugin_info.multiModule = {
            basePackage = multi_module_mappings[normalized].package,
            module = multi_module_mappings[normalized].module,
            repository = normalized:match("^(.+)/") .. "/" .. multi_module_mappings[normalized].package:gsub("%-nvim$", ".nvim")
          }
          extraction_report.multi_module_plugins = extraction_report.multi_module_plugins + 1
        end
        
        -- Track mapping status
        if is_plugin_mapped(normalized) then
          extraction_report.mapped_plugins = extraction_report.mapped_plugins + 1
        else
          extraction_report.unmapped_plugins = extraction_report.unmapped_plugins + 1
          table.insert(unmapped_plugins, normalized)
        end
        
        table.insert(plugins, plugin_info)
      end
    elseif type(spec) == "table" then
      -- Handle table spec
      local name = spec[1] or spec.name
      if name and type(name) == "string" then
        local normalized = normalize_name(name)
        
        -- Only process if it's in owner/repo format
        if normalized and not seen[normalized] then
          seen[normalized] = true
          
          -- Normalize dependencies
          local deps = normalize_deps(spec.dependencies)
          
          -- Extract repository info
          local owner, repo = normalized:match("^([^/]+)/(.+)$")

          -- Check if plugin has mapping
          local plugin_info = {
            name = normalized,
            owner = owner,
            repo = repo,
            dependencies = deps,
            event = spec.event,
            cmd = spec.cmd,
            ft = spec.ft,
            enabled = spec.enabled,
            lazy = spec.lazy,
            priority = spec.priority,
            source_file = "table_spec",
            -- Extract version/commit if specified in spec
            version_info = {
              commit = spec.commit or spec.tag or spec.version,
              tag = spec.tag,
              sha256 = nil  -- To be filled by update script
            }
          }
          
          -- Add multi-module info if applicable
          if multi_module_mappings[normalized] then
            plugin_info.multiModule = {
              basePackage = multi_module_mappings[normalized].package,
              module = multi_module_mappings[normalized].module,
              repository = normalized:match("^(.+)/") .. "/" .. multi_module_mappings[normalized].package:gsub("%-nvim$", ".nvim")
            }
            extraction_report.multi_module_plugins = extraction_report.multi_module_plugins + 1
          end
          
          -- Track mapping status
          if is_plugin_mapped(normalized) then
            extraction_report.mapped_plugins = extraction_report.mapped_plugins + 1
          else
            extraction_report.unmapped_plugins = extraction_report.unmapped_plugins + 1
            table.insert(unmapped_plugins, normalized)
          end
          
          table.insert(plugins, plugin_info)
        end
      end
      
      -- Recursively process nested specs
      for _, v in ipairs(spec) do
        if type(v) == "table" or type(v) == "string" then
          collect_plugin(v)
        end
      end
      
      -- Process dependencies
      if spec.dependencies then
        if type(spec.dependencies) == "table" then
          for _, dep in ipairs(spec.dependencies) do
            collect_plugin(dep)
          end
        end
      end
    end
  end
  
  -- Load core LazyVim plugins
  local core_specs = {
    { "folke/lazy.nvim", version = "*" },
    { "LazyVim/LazyVim", priority = 10000, lazy = false, version = "*" },
    { "folke/snacks.nvim", priority = 1000, lazy = false },
  }
  
  for _, spec in ipairs(core_specs) do
    collect_plugin(spec)
  end
  
  -- Try to load LazyVim plugin modules
  local plugin_modules = {
    "coding", "colorscheme", "editor", "formatting",
    "linting", "lsp", "treesitter", "ui", "util"
  }
  
  for _, module in ipairs(plugin_modules) do
    local ok, module_specs = pcall(function()
      package.loaded["lazyvim.plugins." .. module] = nil
      return require("lazyvim.plugins." .. module)
    end)
    
    if ok and type(module_specs) == "table" then
      for _, spec in ipairs(module_specs) do
        collect_plugin(spec)
      end
    end
  end
  
  -- Add common plugins that might be in extras
  local extra_plugins = {
    "neovim/nvim-lspconfig",
    "nvim-neo-tree/neo-tree.nvim", 
    "nvim-lualine/lualine.nvim",
    "akinsho/bufferline.nvim",
    "folke/noice.nvim",
    "rcarriga/nvim-notify",
    "nvimdev/dashboard-nvim",
    "echasnovski/mini.icons",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    "ibhagwan/fzf-lua",
    "kdheepak/lazygit.nvim",
    "RRethy/vim-illuminate",
    "dstein64/vim-startuptime",
    "nvim-treesitter/nvim-treesitter-context",
    "folke/neoconf.nvim",
    "folke/neodev.nvim",
    "rafamadriz/friendly-snippets",
    "saghen/blink.cmp",
  }
  
  for _, plugin_name in ipairs(extra_plugins) do
    if not seen[plugin_name] then
      seen[plugin_name] = true
      
      -- Extract repository info
      local owner, repo = plugin_name:match("^([^/]+)/(.+)$")

      local plugin_info = {
        name = plugin_name,
        owner = owner,
        repo = repo,
        dependencies = {},
        source_file = "extra",
        -- Placeholder for version info
        version_info = {
          commit = nil,
          tag = nil,
          sha256 = nil
        }
      }
      
      -- Add multi-module info if applicable
      if multi_module_mappings[plugin_name] then
        plugin_info.multiModule = {
          basePackage = multi_module_mappings[plugin_name].package,
          module = multi_module_mappings[plugin_name].module,
          repository = plugin_name:match("^(.+)/") .. "/" .. multi_module_mappings[plugin_name].package:gsub("%-nvim$", ".nvim")
        }
        extraction_report.multi_module_plugins = extraction_report.multi_module_plugins + 1
      end
      
      -- Track mapping status
      if is_plugin_mapped(plugin_name) then
        extraction_report.mapped_plugins = extraction_report.mapped_plugins + 1
      else
        extraction_report.unmapped_plugins = extraction_report.unmapped_plugins + 1
        table.insert(unmapped_plugins, plugin_name)
      end
      
      table.insert(plugins, plugin_info)
    end
  end
  
  -- Scan for user plugins and merge them with core plugins
  print("=== Scanning for user plugins ===")
  local user_plugins = user_scanner.scan_user_plugins()

  if #user_plugins > 0 then
    print(string.format("Found %d user plugins, merging with core plugins", #user_plugins))

    -- Process user plugins through the same logic as core plugins
    for _, user_plugin in ipairs(user_plugins) do
      if not seen[user_plugin.name] then
        seen[user_plugin.name] = true

        -- Mark as user plugin and track mapping status
        user_plugin.user_plugin = true
        user_plugin.source_file = "user_config"

        if is_plugin_mapped(user_plugin.name) then
          extraction_report.mapped_plugins = extraction_report.mapped_plugins + 1
        else
          extraction_report.unmapped_plugins = extraction_report.unmapped_plugins + 1
          table.insert(unmapped_plugins, user_plugin.name)
        end

        table.insert(plugins, user_plugin)
      else
        print(string.format("Skipping user plugin %s (already exists in core)", user_plugin.name))
      end
    end
  else
    print("No user plugins found")
  end

  -- Sort and assign load order
  table.sort(plugins, function(a, b)
    return a.name < b.name
  end)

  for i, plugin in ipairs(plugins) do
    plugin.loadOrder = i
  end

  -- Finalize extraction report
  extraction_report.total_plugins = #plugins
  
  -- Generate mapping suggestions for unmapped plugins
  if #unmapped_plugins > 0 then
    -- Check if verification is requested via environment variable
    local verify_packages = os.getenv("VERIFY_NIXPKGS_PACKAGES") == "1"
    
    local analysis = suggest_mappings.analyze_unmapped_plugins(unmapped_plugins, verify_packages)
    extraction_report.mapping_suggestions = suggest_mappings.generate_mapping_updates(analysis)
    
    -- Write mapping analysis report
    local report_content = suggest_mappings.format_report(analysis)
    local report_file = io.open("mapping-analysis-report.md", "w")
    if report_file then
      report_file:write(report_content)
      report_file:close()
      print("Generated mapping analysis report: mapping-analysis-report.md")
    end
  end
  
  -- Create JSON output
  local json_data = {
    version = version,
    commit = commit,
    generated = os.date("%Y-%m-%d %H:%M:%S"),
    extraction_report = extraction_report,
    plugins = plugins
  }
  
  -- JSON serialization
  local function to_json(data, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    
    if type(data) == "table" then
      if #data > 0 and not data.name then
        -- Array
        local result = "[\n"
        for i, v in ipairs(data) do
          result = result .. spaces .. "  " .. to_json(v, indent + 1)
          if i < #data then result = result .. "," end
          result = result .. "\n"
        end
        return result .. spaces .. "]"
      else
        -- Object
        local result = "{\n"
        local first = true
        local ordered_keys = {"version", "commit", "generated", "extraction_report", "plugins", "name", "owner", "repo", "loadOrder", "dependencies", "multiModule", "source_file", "event", "cmd", "ft", "enabled", "lazy", "priority", "version_info", "total_plugins", "mapped_plugins", "unmapped_plugins", "multi_module_plugins", "mapping_suggestions", "basePackage", "module", "repository", "tag", "sha256"}
        
        for _, k in ipairs(ordered_keys) do
          local v = data[k]
          if v ~= nil then
            if not first then result = result .. ",\n" end
            first = false
            result = result .. spaces .. '  "' .. k .. '": ' .. to_json(v, indent + 1)
          end
        end
        
        if not first then result = result .. "\n" end
        return result .. spaces .. "}"
      end
    elseif type(data) == "string" then
      return '"' .. data:gsub('"', '\\"') .. '"'
    elseif type(data) == "boolean" then
      return tostring(data)
    elseif type(data) == "number" then
      return tostring(data)
    else
      return "null"
    end
  end
  
  -- Write output
  local file = io.open(output_file, "w")
  if file then
    file:write(to_json(json_data))
    file:close()
    
    -- Print extraction summary
    print("=== Plugin Extraction Summary ===")
    print(string.format("Total plugins extracted: %d", extraction_report.total_plugins))
    print(string.format("Mapped plugins: %d", extraction_report.mapped_plugins))
    print(string.format("Unmapped plugins: %d", extraction_report.unmapped_plugins))
    print(string.format("Multi-module plugins: %d", extraction_report.multi_module_plugins))
    
    if extraction_report.unmapped_plugins > 0 then
      print(string.format("Mapping suggestions generated: %d", #extraction_report.mapping_suggestions))
      print("Review mapping-analysis-report.md for details on unmapped plugins")
    end
    
    print("Successfully extracted " .. #plugins .. " plugins")
  else
    error("Failed to write output file")
  end
end