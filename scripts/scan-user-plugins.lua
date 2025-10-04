-- User Plugin Scanner for LazyVim Configuration Files
-- This script scans ~/.config/nvim/lua/plugins/*.lua files to extract custom plugin specifications

local function scan_user_plugins(config_path)
	config_path = config_path or (os.getenv("HOME") .. "/.config/nvim")
	local plugins_dir = config_path .. "/lua/plugins"

	-- Get the correct uv module (vim.uv in newer Neovim, vim.loop in older)
	local uv = vim.uv or vim.loop

	-- Check if plugins directory exists
	local plugins_path_stat = uv.fs_stat(plugins_dir)
	if not plugins_path_stat or plugins_path_stat.type ~= "directory" then
		print("No user plugins directory found at: " .. plugins_dir)
		return {}
	end

	local user_plugins = {}
	local seen_plugins = {}

	-- Function to normalize plugin names (same logic as extract-plugins.lua)
	local function normalize_name(name)
		if type(name) ~= "string" then
			return nil
		end

		-- If it's already in owner/repo format, return as-is
		if name:match("^[%w%-%.]+/[%w%-%._]+$") then
			return name
		end

		return nil
	end

	-- Function to extract plugins from Lua content
	local function extract_plugins_from_content(content, filename)
		local extracted = {}

		-- Pattern 1: Simple string specs like { "owner/repo" }
		for plugin_name in content:gmatch('{"([%w%-%.]+/[%w%-%._]+)"[^}]*}') do
			local normalized = normalize_name(plugin_name)
			if normalized and not seen_plugins[normalized] then
				seen_plugins[normalized] = true
				local owner, repo = normalized:match("^([^/]+)/(.+)$")
				if owner and repo then
					table.insert(extracted, {
						name = normalized,
						owner = owner,
						repo = repo,
						source_file = filename,
						dependencies = {},
						version_info = {
							commit = nil,
							tag = nil,
							sha256 = nil,
						},
					})
				end
			end
		end

		-- Pattern 2: Quote-wrapped specs like { "owner/repo", opts = {...} }
		for plugin_name in content:gmatch('"([%w%-%.]+/[%w%-%._]+)"[^,}]*[,}]') do
			local normalized = normalize_name(plugin_name)
			if normalized and not seen_plugins[normalized] then
				seen_plugins[normalized] = true
				local owner, repo = normalized:match("^([^/]+)/(.+)$")
				if owner and repo then
					table.insert(extracted, {
						name = normalized,
						owner = owner,
						repo = repo,
						source_file = filename,
						dependencies = {},
						version_info = {
							commit = nil,
							tag = nil,
							sha256 = nil,
						},
					})
				end
			end
		end

		-- Pattern 3: Handle return statements
		-- Extract plugins from return { ... } blocks
		for return_block in content:gmatch("return%s*{([^}]*)}") do
			for plugin_name in return_block:gmatch('"([%w%-%.]+/[%w%-%._]+)"') do
				local normalized = normalize_name(plugin_name)
				if normalized and not seen_plugins[normalized] then
					seen_plugins[normalized] = true
					local owner, repo = normalized:match("^([^/]+)/(.+)$")
					if owner and repo then
						table.insert(extracted, {
							name = normalized,
							owner = owner,
							repo = repo,
							source_file = filename,
							dependencies = {},
							version_info = {
								commit = nil,
								tag = nil,
								sha256 = nil,
							},
						})
					end
				end
			end
		end

		return extracted
	end

	-- Function to scan a directory for Lua files
	local function scan_directory(dir_path)
		local handle = uv.fs_scandir(dir_path)
		if not handle then
			return {}
		end

		local files = {}
		repeat
			local name, type = uv.fs_scandir_next(handle)
			if name then
				if type == "file" and name:match("%.lua$") then
					table.insert(files, dir_path .. "/" .. name)
				end
			end
		until not name

		return files
	end

	-- Scan all Lua files in the plugins directory
	local plugin_files = scan_directory(plugins_dir)

	for _, file_path in ipairs(plugin_files) do
		local file = io.open(file_path, "r")
		if file then
			local content = file:read("*all")
			file:close()

			local filename = file_path:match("[^/]+$")
			local plugins_in_file = extract_plugins_from_content(content, filename)

			for _, plugin in ipairs(plugins_in_file) do
				table.insert(user_plugins, plugin)
			end

			if #plugins_in_file > 0 then
				print(string.format("Found %d plugins in %s", #plugins_in_file, filename))
			end
		else
			print("Warning: Could not read file " .. file_path)
		end
	end

	-- Sort plugins by name for consistency
	table.sort(user_plugins, function(a, b)
		return a.name < b.name
	end)

	print(string.format("Total user plugins discovered: %d", #user_plugins))

	return user_plugins
end

-- Function to merge user plugins with core plugins
local function merge_plugins(core_plugins, user_plugins)
	local merged = {}
	local seen = {}

	-- Add core plugins first
	for _, plugin in ipairs(core_plugins) do
		if not seen[plugin.name] then
			seen[plugin.name] = true
			table.insert(merged, plugin)
		end
	end

	-- Add user plugins that aren't already in core
	for _, plugin in ipairs(user_plugins) do
		if not seen[plugin.name] then
			seen[plugin.name] = true
			-- Mark as user plugin for identification
			plugin.user_plugin = true
			table.insert(merged, plugin)
		else
			print(string.format("Skipping user plugin %s (already in core)", plugin.name))
		end
	end

	return merged
end

-- Export functions for use by other scripts
return {
	scan_user_plugins = scan_user_plugins,
	merge_plugins = merge_plugins,
}
