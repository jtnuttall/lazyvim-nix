#!/usr/bin/env lua

-- Extract plugin specs from LazyVim extras files
-- This script parses enabled extras and extracts their plugin dependencies

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

local function write_json(data, path)
  local file = io.open(path, "w")
  if not file then
    error("Failed to open output file: " .. path)
  end

  -- Simple JSON serialization for our use case
  local function serialize_value(val)
    if type(val) == "string" then
      return '"' .. val:gsub('"', '\\"') .. '"'
    elseif type(val) == "number" then
      return tostring(val)
    elseif type(val) == "boolean" then
      return val and "true" or "false"
    elseif type(val) == "table" then
      if #val > 0 then
        -- Array
        local items = {}
        for _, v in ipairs(val) do
          table.insert(items, serialize_value(v))
        end
        return "[" .. table.concat(items, ",") .. "]"
      else
        -- Object
        local items = {}
        for k, v in pairs(val) do
          table.insert(items, '"' .. k .. '":' .. serialize_value(v))
        end
        return "{" .. table.concat(items, ",") .. "}"
      end
    else
      return "null"
    end
  end

  file:write(serialize_value(data))
  file:close()
end

local function extract_plugins_from_extra(extra_path)
  -- Read the extra file
  local content = read_file(extra_path)
  if not content then
    return {}
  end

  -- Parse the Lua file by loading it in a sandboxed environment
  local plugins = {}

  -- Create a safe environment for loading the extra
  local env = {
    -- Common Lua functions
    pairs = pairs,
    ipairs = ipairs,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    table = table,
    string = string,
    math = math,
  }

  -- Load the extra file
  local chunk, err = load(content, extra_path, "t", env)
  if not chunk then
    io.stderr:write("Failed to parse extra: " .. extra_path .. ": " .. err .. "\n")
    return {}
  end

  -- Execute and get the result
  local success, result = pcall(chunk)
  if not success then
    io.stderr:write("Failed to execute extra: " .. extra_path .. ": " .. result .. "\n")
    return {}
  end

  -- The extra should return a table
  if type(result) ~= "table" then
    return {}
  end

  -- Extract plugin specs from the result
  -- Extras return an array-like table where each entry is either:
  -- 1. A plugin spec table with a plugin name as [1] or a string key
  -- 2. Metadata like "recommended"
  for _, item in ipairs(result) do
    if type(item) == "table" and item[1] and type(item[1]) == "string" then
      -- This is a plugin spec
      local plugin_name = item[1]

      -- Extract owner/repo from the plugin name
      local owner, repo = plugin_name:match("^([^/]+)/(.+)$")
      if owner and repo then
        table.insert(plugins, {
          name = plugin_name,
          owner = owner,
          repo = repo,
          source_file = "extra",
          extra_plugin = true
        })
      end
    end
  end

  return plugins
end

-- Main execution
local function main(args)
  if #args < 2 then
    io.stderr:write("Usage: extract-extras-plugins.lua <extras-dir> <output-json> [extra1.lua extra2.lua ...]\n")
    os.exit(1)
  end

  local extras_dir = args[1]
  local output_path = args[2]
  local extras_to_parse = {}

  -- Collect extras to parse from remaining args
  for i = 3, #args do
    table.insert(extras_to_parse, args[i])
  end

  -- Extract plugins from all specified extras
  local all_plugins = {}
  local seen = {}

  for _, extra_file in ipairs(extras_to_parse) do
    local extra_path = extras_dir .. "/" .. extra_file
    local plugins = extract_plugins_from_extra(extra_path)

    -- Deduplicate plugins
    for _, plugin in ipairs(plugins) do
      if not seen[plugin.name] then
        seen[plugin.name] = true
        table.insert(all_plugins, plugin)
      end
    end
  end

  -- Write output
  write_json(all_plugins, output_path)

  io.stderr:write(string.format("Extracted %d plugins from %d extras\n",
    #all_plugins, #extras_to_parse))
end

-- Run main with command-line arguments
main(arg)
