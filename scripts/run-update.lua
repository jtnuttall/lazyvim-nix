#!/usr/bin/env lua

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("^(.*)/")
package.path = script_dir .. '/?.lua;' .. package.path

-- Load plugin extractor (defines global function)
dofile(script_dir .. "/extract-plugins.lua")
local extras_runner = require("extract-extras")
local extras_scan = require("lib.extras_scan")

local function usage()
  print("Usage: run-update.lua <lazyvim_path> <plugins_output> <dependencies_output> <treesitter_output> <mason_path> <lazyvim_version> <lazyvim_commit> <extras_cache_root>")
  os.exit(1)
end

local function main()
  local lazyvim_path = arg[1]
  local plugins_output = arg[2]
  local dependencies_output = arg[3]
  local treesitter_output = arg[4]
  local mason_path = arg[5]
  local lazyvim_version = arg[6]
  local lazyvim_commit = arg[7]
  local extras_cache_root = arg[8]

  if not (lazyvim_path and plugins_output and dependencies_output and treesitter_output and lazyvim_version and lazyvim_commit) then
    usage()
  end

  if mason_path == "" then
    mason_path = nil
  end

  local extras_entries = extras_scan.collect(lazyvim_path)
  ExtractLazyVimPlugins(lazyvim_path, plugins_output, lazyvim_version, lazyvim_commit, {
    extras_entries = extras_entries,
  })
  extras_runner.run(lazyvim_path, mason_path, dependencies_output, treesitter_output, extras_cache_root, extras_entries)
end

main()
