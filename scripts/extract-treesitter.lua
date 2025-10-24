#!/usr/bin/env lua

-- Script to extract treesitter parser requirements from LazyVim
-- Generates treesitter-mappings.json for use in module.nix

local extras_scan = require("lib.extras_scan")

-- JSON encoder with pretty printing support
local function encode_json(obj, indent, current_indent)
  indent = indent or 0
  current_indent = current_indent or 0
  local spaces = string.rep("  ", current_indent)
  local next_spaces = string.rep("  ", current_indent + 1)

  if type(obj) == "table" then
    -- Check if it's an array (consecutive integer keys starting from 1)
    local is_array = true
    local count = 0
    for k, _ in pairs(obj) do
      count = count + 1
      if type(k) ~= "number" or k ~= count then
        is_array = false
        break
      end
    end

    if is_array then
      if count == 0 then
        return "[]"
      end
      local items = {}
      for i = 1, count do
        table.insert(items, next_spaces .. encode_json(obj[i], indent, current_indent + 1))
      end
      return "[\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "]"
    else
      local items = {}
      local keys = {}
      for k in pairs(obj) do
        table.insert(keys, k)
      end
      table.sort(keys)

      for _, k in ipairs(keys) do
        local v = obj[k]
        local value_str = encode_json(v, indent, current_indent + 1)
        table.insert(items, next_spaces .. '"' .. k .. '": ' .. value_str)
      end

      if #items == 0 then
        return "{}"
      end
      return "{\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "}"
    end
  elseif type(obj) == "string" then
    return '"' .. obj .. '"'
  elseif type(obj) == "number" then
    return tostring(obj)
  elseif type(obj) == "boolean" then
    return obj and "true" or "false"
  else
    return "null"
  end
end

local function read_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Helper function to extract parsers from ensure_installed
local function extract_parsers_from_content(content)
  local parsers = {}

  local treesitter_pattern = '"nvim%-treesitter/nvim%-treesitter"[^}]-}'
  local treesitter_block = content:match(treesitter_pattern)

  if not treesitter_block then
    return parsers
  end

  local patterns = {
    'opts%s*=%s*{[^}]*ensure_installed%s*=%s*{%s*([^}]-)%s*}',
    'opts%s*=%s*function%(%).-ensure_installed%s*=%s*{%s*([^}]-)%s*}'
  }

  for _, pattern in ipairs(patterns) do
    local match = treesitter_block:match(pattern)
    if match then
      for parser in match:gmatch('"([^"]+)"') do
        table.insert(parsers, parser)
      end
      break
    end
  end

  return parsers
end

-- Extract core treesitter parsers from main treesitter configuration
local function extract_core_parsers(lazyvim_repo)
  local treesitter_file = lazyvim_repo .. "/lua/lazyvim/plugins/treesitter.lua"
  local content = read_file(treesitter_file)

  if not content then
    error("Could not read treesitter.lua file: " .. treesitter_file)
  end

  local parsers = {}
  local pattern = 'ensure_installed%s*=%s*{%s*([^}]-)%s*}'
  local match = content:match(pattern)

  if match then
    for parser in match:gmatch('"([^"]+)"') do
      table.insert(parsers, parser)
    end
  end

  if #parsers == 0 then
    error("No core parsers found in treesitter.lua")
  end

  return parsers
end

local function extract_extra_parsers_from_entries(entries, cache_ops)
  local extras = {}

  for _, entry in ipairs(entries) do
    if entry.module:match("^lang%.") then
      local content = entry.content
      local cached = nil
      if cache_ops and entry.hash and cache_ops.get_parsers then
        cached = cache_ops.get_parsers(entry.hash)
      end

      if cached then
        extras[entry.module] = cached
      elseif content and content:match('"nvim%-treesitter/nvim%-treesitter"') then
        local parsers = extract_parsers_from_content(content)
        if #parsers > 0 then
          extras[entry.module] = parsers
          if cache_ops and entry.hash and cache_ops.store_parsers then
            cache_ops.store_parsers(entry.hash, parsers)
          end
        end
      end
    end
  end

  return extras
end

local function generate_mappings(lazyvim_repo, extras_entries, output_file, cache_ops)
  output_file = output_file or "data/treesitter.json"
  extras_entries = extras_entries or extras_scan.collect(lazyvim_repo)

  print("Extracting treesitter parsers from LazyVim...")
  print("LazyVim repo: " .. lazyvim_repo)
  print("")

  print("Extracting core parsers...")
  local core_parsers = extract_core_parsers(lazyvim_repo)
  print("Found " .. #core_parsers .. " core parsers")

  print("Extracting extra parsers...")
  local extra_parsers = extract_extra_parsers_from_entries(extras_entries, cache_ops)
  local extra_count = 0
  local extra_category_count = 0
  for _, parsers in pairs(extra_parsers) do
    extra_count = extra_count + #parsers
    extra_category_count = extra_category_count + 1
  end

  print("Found " .. extra_count .. " extra parsers across " .. extra_category_count .. " language extras")

  local mappings = {
    core = core_parsers,
    extras = extra_parsers
  }

  local json_output = encode_json(mappings)
  print("")
  print("Generated treesitter mappings:")
  print(json_output)

  local file = io.open(output_file, "w")
  if file then
    file:write(json_output)
    file:close()
    print("")
    print("✓ Wrote mappings to " .. output_file)
  else
    error("Could not write to " .. output_file)
  end

  return mappings
end

local function main()
  local lazyvim_repo = arg[1]
  local output_file = arg[2] or "data/treesitter.json"

  if not lazyvim_repo then
    print("Usage: extract-treesitter.lua <lazyvim_repo_path> [output_file]")
    os.exit(1)
  end

  generate_mappings(lazyvim_repo, nil, output_file)
end

if arg and arg[0] and arg[0]:match("extract%-treesitter") then
  main()
end

return {
  generate_mappings = generate_mappings,
  extract_core_parsers = extract_core_parsers,
  extract_parsers_from_content = extract_parsers_from_content,
  extract_extra_parsers_from_entries = extract_extra_parsers_from_entries,
}
