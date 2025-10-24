#!/usr/bin/env lua

local extras_scan = require("lib.extras_scan")
local dependencies = require("extract-dependencies")
local treesitter = require("extract-treesitter")

local M = {}

local function ensure_dir(path)
  if not path or path == "" then
    return
  end
  if vim and vim.fn and vim.fn.mkdir then
    vim.fn.mkdir(path, "p")
  else
    os.execute(string.format("mkdir -p '%s'", path))
  end
end

local function load_json(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if ok then
    return decoded
  end
  return nil
end

local function save_json(path, data)
  local content = vim.json.encode(data)
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
end

local function build_cache_ops(cache_root)
  ensure_dir(cache_root)
  local tools_dir = cache_root .. "/dependencies"
  local parsers_dir = cache_root .. "/treesitter"
  ensure_dir(tools_dir)
  ensure_dir(parsers_dir)

  return {
    get_tools = function(hash)
      if not hash then return nil end
      return load_json(tools_dir .. "/" .. hash .. ".json")
    end,
    store_tools = function(hash, data)
      if not hash or not data then return end
      save_json(tools_dir .. "/" .. hash .. ".json", data)
    end,
    get_parsers = function(hash)
      if not hash then return nil end
      return load_json(parsers_dir .. "/" .. hash .. ".json")
    end,
    store_parsers = function(hash, data)
      if not hash or not data then return end
      save_json(parsers_dir .. "/" .. hash .. ".json", data)
    end,
  }
end

function M.run(lazyvim_path, mason_path, dependencies_output, treesitter_output, cache_root, extras_entries)
  local cache_ops = nil
  if cache_root and cache_root ~= "" then
    cache_ops = build_cache_ops(cache_root)
  end

  extras_entries = extras_entries or extras_scan.collect(lazyvim_path)
  dependencies.extract_dependencies(lazyvim_path, mason_path, dependencies_output, extras_entries, cache_ops)
  treesitter.generate_mappings(lazyvim_path, extras_entries, treesitter_output, cache_ops)
end

local function main()
  local lazyvim_path = arg[1]
  local mason_path = arg[2]
  local dependencies_output = arg[3] or "data/dependencies.json"
  local treesitter_output = arg[4] or "data/treesitter.json"
  local cache_root = arg[5]

  if not lazyvim_path then
    print("Usage: extract-extras.lua <lazyvim_path> [mason_path] [dependencies_output] [treesitter_output] [cache_root]")
    os.exit(1)
  end

  if mason_path == "" then
    mason_path = nil
  end

  M.run(lazyvim_path, mason_path, dependencies_output, treesitter_output, cache_root)
end

if arg and arg[0] and arg[0]:match("extract%-extras") then
  main()
end

return M
