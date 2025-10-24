-- Utility to scan LazyVim extras only once and share file content consumers

local M = {}

local cache = {}

local function shell_escape(path)
  return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

local function compute_hash(content)
  if type(vim) == "table" and vim.fn and vim.fn.sha256 then
    return vim.fn.sha256(content)
  end
  return nil
end

local function collect_files(extras_root)
  local files = {}
  local command = string.format("find %s -type f -name '*.lua' | sort", shell_escape(extras_root))
  local handle = io.popen(command)
  if not handle then
    return files
  end

  for path in handle:lines() do
    table.insert(files, path)
  end

  handle:close()
  return files
end

function M.collect(lazyvim_path)
  if cache[lazyvim_path] then
    return cache[lazyvim_path]
  end

  local extras_root = lazyvim_path .. "/lua/lazyvim/plugins/extras"
  local files = collect_files(extras_root)
  local entries = {}

  for _, file_path in ipairs(files) do
    local content = read_file(file_path)
    if content then
      local relative = file_path:sub(#extras_root + 2)
      local module = relative:gsub("%.lua$", ""):gsub("/", ".")
      table.insert(entries, {
        path = file_path,
        relative = relative,
        module = module,
        content = content,
        hash = compute_hash(content),
      })
    end
  end

  cache[lazyvim_path] = entries
  return entries
end

function M.clear()
  cache = {}
end

return M
