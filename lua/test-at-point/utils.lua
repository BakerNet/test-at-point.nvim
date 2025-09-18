---@class TestAtPointUtils
local M = {}

---Logger levels
M.log_levels = {
  TRACE = 0,
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

---Current log level
M._log_level = M.log_levels.INFO

---Set log level
---@param level number
function M.set_log_level(level)
  M._log_level = level
end

---Log a message
---@param level number Log level
---@param message string Message to log
---@param ... any Additional arguments
local function log_message(level, message, ...)
  if level < M._log_level then
    return
  end
  
  local level_names = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
  local level_name = level_names[level + 1] or "UNKNOWN"
  
  local formatted = string.format(message, ...)
  local log_msg = string.format("[test-at-point] [%s] %s", level_name, formatted)
  
  -- Use appropriate vim.notify level
  local vim_level = vim.log.levels.INFO
  if level >= M.log_levels.ERROR then
    vim_level = vim.log.levels.ERROR
  elseif level >= M.log_levels.WARN then
    vim_level = vim.log.levels.WARN
  end
  
  vim.notify(log_msg, vim_level)
end

---Logger functions
M.log = {
  trace = function(message, ...) log_message(M.log_levels.TRACE, message, ...) end,
  debug = function(message, ...) log_message(M.log_levels.DEBUG, message, ...) end,
  info = function(message, ...) log_message(M.log_levels.INFO, message, ...) end,
  warn = function(message, ...) log_message(M.log_levels.WARN, message, ...) end,
  error = function(message, ...) log_message(M.log_levels.ERROR, message, ...) end,
}

---Check if a command exists
---@param cmd string Command name
---@return boolean
function M.command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

---Find project root directory
---@param markers string[] Root marker files
---@param start_path? string Starting path (default: current file)
---@return string? Project root path
function M.find_project_root(markers, start_path)
  start_path = start_path or vim.fn.expand('%:p:h')
  
  if start_path == '' then
    start_path = vim.fn.getcwd()
  end
  
  local current_dir = start_path
  
  while current_dir ~= '/' do
    for _, marker in ipairs(markers) do
      local marker_path = current_dir .. '/' .. marker
      if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
        return current_dir
      end
    end
    
    local parent = vim.fn.fnamemodify(current_dir, ':h')
    if parent == current_dir then
      break
    end
    current_dir = parent
  end
  
  return nil
end

---Get relative path from project root
---@param file_path string Absolute file path
---@param project_root? string Project root (auto-detected if not provided)
---@return string Relative path
function M.get_relative_path(file_path, project_root)
  if not project_root then
    -- Try to find project root with common markers
    project_root = M.find_project_root({
      '.git', 'Cargo.toml', 'go.mod', 'package.json', 'pyproject.toml', 'Makefile'
    }, vim.fn.fnamemodify(file_path, ':h'))
  end
  
  if project_root and vim.startswith(file_path, project_root) then
    return file_path:sub(#project_root + 2) -- +2 to remove leading slash
  end
  
  return vim.fn.fnamemodify(file_path, ':t') -- Just filename if no project root
end

---Escape special characters for shell command
---@param str string String to escape
---@return string Escaped string
function M.shell_escape(str)
  -- Simple shell escaping - wrap in single quotes and escape single quotes
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

---Split string by delimiter
---@param str string String to split
---@param delimiter string Delimiter
---@return string[] Array of strings
function M.split(str, delimiter)
  local result = {}
  local pattern = string.format("([^%s]+)", delimiter)
  
  for match in str:gmatch(pattern) do
    table.insert(result, match)
  end
  
  return result
end

---Trim whitespace from string
---@param str string String to trim
---@return string Trimmed string
function M.trim(str)
  return str:match("^%s*(.-)%s*$")
end

---Check if string starts with prefix
---@param str string String to check
---@param prefix string Prefix to check for
---@return boolean
function M.starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

---Check if string ends with suffix
---@param str string String to check
---@param suffix string Suffix to check for
---@return boolean
function M.ends_with(str, suffix)
  return str:sub(-#suffix) == suffix
end

---Deep copy a table
---@param obj any Object to copy
---@return any Copied object
function M.deepcopy(obj)
  return vim.deepcopy(obj)
end

---Check if table is empty
---@param tbl table Table to check
---@return boolean
function M.is_empty(tbl)
  return next(tbl) == nil
end

---Merge two arrays
---@param arr1 table First array
---@param arr2 table Second array
---@return table Merged array
function M.merge_arrays(arr1, arr2)
  local result = vim.deepcopy(arr1)
  for _, item in ipairs(arr2) do
    table.insert(result, item)
  end
  return result
end

---Get current buffer info
---@param bufnr? number Buffer number
---@return table Buffer information
function M.get_buffer_info(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  local cursor = vim.api.nvim_win_get_cursor(0)
  
  return {
    bufnr = bufnr,
    file_path = file_path,
    filetype = filetype,
    line = cursor[1],
    column = cursor[2] + 1, -- Convert to 1-based
    relative_path = M.get_relative_path(file_path)
  }
end

---Format a test name for display
---@param test_info table Test information
---@return string Formatted test name
function M.format_test_name(test_info)
  local file_name = vim.fn.fnamemodify(test_info.file_path, ':t')
  return string.format("%s::%s", file_name, test_info.name)
end

---Check if Treesitter is available for filetype
---@param filetype string File type to check
---@return boolean
function M.has_treesitter(filetype)
  local has_treesitter, parsers = pcall(require, 'nvim-treesitter.parsers')
  if not has_treesitter then
    return false
  end
  
  return parsers.has_parser(filetype)
end

---Get Neovim version info
---@return table Version information
function M.get_neovim_version()
  local version = vim.version()
  return {
    major = version.major,
    minor = version.minor,
    patch = version.patch,
    string = string.format("%d.%d.%d", version.major, version.minor, version.patch)
  }
end

---Check if current Neovim version meets minimum requirement
---@param min_version string Minimum version (e.g., "0.8.0")
---@return boolean
function M.check_neovim_version(min_version)
  local current = M.get_neovim_version()
  local min_parts = M.split(min_version, ".")
  
  local min_major = tonumber(min_parts[1]) or 0
  local min_minor = tonumber(min_parts[2]) or 0
  local min_patch = tonumber(min_parts[3]) or 0
  
  if current.major > min_major then return true end
  if current.major < min_major then return false end
  
  if current.minor > min_minor then return true end
  if current.minor < min_minor then return false end
  
  return current.patch >= min_patch
end

---Create a debounced function
---@param fn function Function to debounce
---@param delay number Delay in milliseconds
---@return function Debounced function
function M.debounce(fn, delay)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      timer:stop()
    end
    timer = vim.defer_fn(function()
      fn(unpack(args))
    end, delay)
  end
end

---Create a throttled function
---@param fn function Function to throttle
---@param delay number Delay in milliseconds
---@return function Throttled function
function M.throttle(fn, delay)
  local last_call = 0
  return function(...)
    local now = vim.loop.hrtime() / 1000000 -- Convert to milliseconds
    if now - last_call >= delay then
      last_call = now
      fn(...)
    end
  end
end

return M