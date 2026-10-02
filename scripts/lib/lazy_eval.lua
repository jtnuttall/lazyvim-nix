-- Resolve LazyVim's plugin specs with lazy.nvim itself (the extractor already
-- runs under headless nvim) and read each plugin's merged `opts` exactly as
-- LazyVim would see them at startup.
--
-- Nothing is installed or loaded. lazy.nvim parses the spec tree (LazyVim core
-- plus the requested extras) and merges every plugin's opts across its specs
-- with its own rules (opts functions, opts_extend, ...). Plugin modules that
-- are not present (lspconfig, snacks, ...) resolve to inert proxies so the
-- opts functions that reference them still run.

local M = {}

M.warnings = {}

local proxy_mt = {}

local function proxy()
    return setmetatable({}, proxy_mt)
end

proxy_mt.__index = function(self, key)
    if type(key) == "number" then
        return nil
    end
    local value = proxy()
    rawset(self, key, value)
    return value
end
proxy_mt.__call = function()
    return proxy()
end
proxy_mt.__len = function()
    return 0
end
proxy_mt.__tostring = function()
    return ""
end
proxy_mt.__concat = function(a, b)
    return (type(a) == "string" and a or "") .. (type(b) == "string" and b or "")
end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm" }) do
    proxy_mt[op] = function()
        return 0
    end
end
proxy_mt.__lt = function()
    return false
end
proxy_mt.__le = function()
    return false
end

local scratch

-- lazy.nvim's Plugin._values, with one change: an opts function that throws
-- contributes nothing instead of aborting the whole merge (an extra may poke
-- at a server another extra defines, e.g. vue.lua and vtsls).
local function tolerant_values(Plugin, Util)
    return function(root, plugin, prop, is_list)
        if not plugin[prop] then
            return {}
        end
        local super = getmetatable(plugin)
        local ret = super and Plugin._values(root, super.__index, prop, is_list) or {}
        local values = rawget(plugin, prop)

        if not values then
            return ret
        elseif type(values) == "function" then
            local ok, result = pcall(values, root, ret)
            if not ok then
                table.insert(M.warnings, string.format("%s: opts function failed: %s", plugin.name, tostring(result)))
                return ret
            end
            ret = result or ret
            return type(ret) == "table" and ret or { ret }
        end

        values = type(values) == "table" and values or { values }
        if is_list then
            return Util.extend(ret, values)
        end
        local lists = {}
        for _, key in ipairs(plugin[prop .. "_extend"] or {}) do
            local path = vim.split(key, ".", { plain = true })
            local r = Util.key_get(ret, path)
            local v = Util.key_get(values, path)
            if type(r) == "table" and type(v) == "table" then
                lists[key] = { path = path, list = {} }
                vim.list_extend(lists[key].list, r)
                vim.list_extend(lists[key].list, v)
            end
        end
        local merged = Util.merge(ret, values)
        for _, list in pairs(lists) do
            Util.key_set(merged, list.path, list.list)
        end
        return merged
    end
end

function M.setup(lazy_path, lazyvim_path, scratch_dir)
    if scratch then
        return
    end
    scratch = scratch_dir
    vim.fn.mkdir(scratch, "p")

    vim.opt.rtp:prepend(lazy_path)
    vim.opt.rtp:prepend(lazyvim_path)
    package.loaded["lazy.core.cache"] = vim.loader
    vim.loader.enable()

    -- last-resort module loader: absent plugin modules become proxies
    table.insert(package.loaders, function()
        return function()
            return proxy()
        end
    end)

    -- LazyVim reads its json settings from stdpath("config"); point it at
    -- nothing so the defaults apply
    vim.g.lazyvim_json = scratch .. "/lazyvim.json"
    _G.LazyVim = require("lazyvim.util")
    if _G.Snacks == nil then
        _G.Snacks = require("snacks")
    end

    local Plugin = require("lazy.core.plugin")
    local Util = require("lazy.core.util")
    Plugin._values = tolerant_values(Plugin, Util)
end

-- LazyVim keeps registries in module state (register_defaults in the
-- typescript extra enables the vtsls sub-extra, json settings, ...), so give
-- every resolve a fresh LazyVim: drop its modules and re-require the util.
local function fresh_lazyvim()
    for name in pairs(package.loaded) do
        if name == "lazyvim" or name:sub(1, 8) == "lazyvim." then
            package.loaded[name] = nil
        end
    end
    os.remove(vim.g.lazyvim_json)
    _G.LazyVim = require("lazyvim.util")
end

-- lazy.nvim's resolved plugin table for LazyVim core plus the given extras
-- (extra module names like "lang.python").
function M.resolve(extras)
    assert(scratch, "lazy_eval.setup() must run first")
    local Config = require("lazy.core.config")
    local Plugin = require("lazy.core.plugin")

    local spec = { { "LazyVim/LazyVim", import = "lazyvim.plugins" } }
    for _, extra in ipairs(extras) do
        table.insert(spec, { import = "lazyvim.plugins.extras." .. extra })
    end

    Config.setup({
        spec = spec,
        root = scratch .. "/lazy",
        lockfile = scratch .. "/lazy-lock.json",
        install = { missing = false },
        rocks = { enabled = false },
        readme = { enabled = false },
        change_detection = { enabled = false, notify = false },
        performance = { rtp = { reset = false } },
    })
    -- Plugin.load() carries per-plugin state (including the merged-opts cache)
    -- over from the previous load; start from nothing each time.

    fresh_lazyvim()
    Config.plugins = {}
    Plugin.load()
    return Config.plugins
end

local function opts_of(plugins, name)
    local plugin = plugins[name]
    if not plugin then
        return nil
    end
    local Plugin = require("lazy.core.plugin")
    local ok, opts = pcall(Plugin.values, plugin, "opts", false)
    if not ok then
        table.insert(M.warnings, string.format("%s: could not resolve opts: %s", name, tostring(opts)))
        return nil
    end
    return opts
end

local function sorted_string_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        if type(key) == "string" then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

-- Tools LazyVim configures for core + extras: lspconfig `servers` (minus the
-- `*` wildcard and servers with `enabled = false`) and Mason /
-- mason-lspconfig `ensure_installed`.
function M.tools(extras)
    local plugins = M.resolve(extras)
    local tools = {}
    local seen = {}
    local function add(tool)
        if type(tool) == "string" and not seen[tool] then
            seen[tool] = true
            table.insert(tools, tool)
        end
    end

    local lsp = opts_of(plugins, "nvim-lspconfig")
    local servers = lsp and rawget(lsp, "servers")
    if type(servers) == "table" then
        for _, server in ipairs(sorted_string_keys(servers)) do
            local config = rawget(servers, server)
            local disabled = type(config) == "table" and rawget(config, "enabled") == false
            if server ~= "*" and not disabled then
                add(server)
            end
        end
    end

    for _, name in ipairs({ "mason.nvim", "mason-lspconfig.nvim" }) do
        local opts = opts_of(plugins, name)
        local list = opts and rawget(opts, "ensure_installed")
        if type(list) == "table" then
            for _, tool in ipairs(list) do
                add(tool)
            end
        end
    end

    return tools
end

-- Treesitter parsers LazyVim configures for core + extras.
function M.parsers(extras)
    local plugins = M.resolve(extras)
    local opts = opts_of(plugins, "nvim-treesitter")
    local list = opts and rawget(opts, "ensure_installed")
    local parsers = {}
    if type(list) == "table" then
        for _, parser in ipairs(list) do
            if type(parser) == "string" then
                table.insert(parsers, parser)
            end
        end
    end
    return parsers
end

-- Drain accumulated warnings.
function M.take_warnings()
    local warnings = M.warnings
    M.warnings = {}
    return warnings
end

return M
