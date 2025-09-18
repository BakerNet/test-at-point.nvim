---@class TestAtPointDetection
local M = {}

local utils = require('test-at-point.utils')
local config = require('test-at-point.config')
local patterns = require('test-at-point.detection.patterns')

---Find test at cursor position
---@param bufnr? number Buffer number (default: current buffer)
---@param line? number Line number (default: cursor line)
---@param col? number Column number (default: cursor column)
---@return table? TestInfo object or nil
function M.find_test_at_cursor(bufnr, line, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not line or not col then
    local cursor = vim.api.nvim_win_get_cursor(0)
    line = line or cursor[1]
    col = col or cursor[2] + 1 -- Convert to 1-based
  end
  
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  local lang_config = config.get_language_config(filetype)
  
  if not lang_config then
    utils.log.warn("No configuration found for filetype: %s", filetype)
    return nil
  end
  
  utils.log.debug("Finding test at cursor in %s file at line %d", filetype, line)
  
  -- Try Treesitter detection first if available and preferred
  if config.get_config().prefer_treesitter and M._has_treesitter(filetype) then
    local treesitter = require('test-at-point.detection.treesitter')
    local result = treesitter.find_test(bufnr, line, col)
    if result then
      utils.log.debug("Found test using treesitter: %s", result.name)
      return result
    end
    utils.log.debug("Treesitter detection failed, falling back to patterns")
  end
  
  -- Fall back to pattern-based detection
  if lang_config.patterns then
    local result = patterns.find_test(bufnr, line, lang_config.patterns)
    if result then
      utils.log.debug("Found test using patterns: %s", result.name)
      return result
    end
  end
  
  utils.log.debug("No test found at cursor position")
  return nil
end

---Find all tests in file
---@param bufnr? number Buffer number (default: current buffer)
---@return table[] Array of TestInfo objects
function M.find_all_tests_in_file(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  local lang_config = config.get_language_config(filetype)
  
  if not lang_config then
    utils.log.warn("No configuration found for filetype: %s", filetype)
    return {}
  end
  
  local tests = {}
  
  -- Try Treesitter detection first if available and preferred
  if config.get_config().prefer_treesitter and M._has_treesitter(filetype) then
    local treesitter = require('test-at-point.detection.treesitter')
    tests = treesitter.find_all_tests(bufnr)
    
    if #tests > 0 then
      utils.log.debug("Found %d tests using treesitter", #tests)
      return tests
    end
    utils.log.debug("Treesitter detection found no tests, falling back to patterns")
  end
  
  -- Fall back to pattern-based detection
  if lang_config.patterns then
    tests = patterns.find_all_tests(bufnr, lang_config.patterns)
    utils.log.debug("Found %d tests using patterns", #tests)
  end
  
  return tests
end

---Get test context at line
---@param bufnr number Buffer number
---@param line number Line number
---@return table? TestContext object or nil
function M.get_test_context(bufnr, line)
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  
  -- Try Treesitter context detection first
  if M._has_treesitter(filetype) then
    local treesitter = require('test-at-point.detection.treesitter')
    local context = treesitter.get_context(bufnr, line)
    if context then
      return context
    end
  end
  
  -- Fall back to pattern-based context detection
  return patterns._get_context(bufnr, line, filetype)
end

---Check if treesitter is available for filetype
---@param filetype string File type
---@return boolean
function M._has_treesitter(filetype)
  return utils.has_treesitter(filetype)
end

---Find test files in directory
---@param path? string Directory path (default: current working directory)
---@param filetype? string Filter by filetype
---@return string[] Array of test file paths
function M.find_test_files(path, filetype)
  path = path or vim.fn.getcwd()
  
  if not vim.fn.isdirectory(path) then
    utils.log.error("Invalid directory path: %s", path)
    return {}
  end
  
  local test_files = {}
  local lang_configs = {}
  
  -- Get language configurations to check
  if filetype then
    local lang_config = config.get_language_config(filetype)
    if lang_config then
      lang_configs[filetype] = lang_config
    end
  else
    lang_configs = config.get_config().languages or {}
  end
  
  -- Collect all test file patterns
  local all_patterns = {}
  for _, lang_config in pairs(lang_configs) do
    if lang_config.test_file_patterns then
      for _, pattern in ipairs(lang_config.test_file_patterns) do
        table.insert(all_patterns, pattern)
      end
    end
  end
  
  if #all_patterns == 0 then
    utils.log.warn("No test file patterns configured")
    return {}
  end
  
  -- Find files matching patterns
  for _, pattern in ipairs(all_patterns) do
    local cmd = string.format("find %s -name '%s' -type f", utils.shell_escape(path), pattern)
    local output = vim.fn.system(cmd)
    
    if vim.v.shell_error == 0 then
      for file_path in output:gmatch("[^\r\n]+") do
        if vim.fn.filereadable(file_path) == 1 then
          table.insert(test_files, file_path)
        end
      end
    end
  end
  
  -- Remove duplicates and sort
  local unique_files = {}
  local seen = {}
  
  for _, file in ipairs(test_files) do
    if not seen[file] then
      seen[file] = true
      table.insert(unique_files, file)
    end
  end
  
  table.sort(unique_files)
  
  utils.log.debug("Found %d test files in %s", #unique_files, path)
  return unique_files
end

---Get source file for test file
---@param test_file_path string Test file path
---@return string? Source file path or nil
function M.get_source_file(test_file_path)
  local filetype = vim.filetype.match({ filename = test_file_path })
  local lang_config = config.get_language_config(filetype or "")
  
  if not lang_config or not lang_config.test_file_patterns then
    return nil
  end
  
  local file_name = vim.fn.fnamemodify(test_file_path, ':t')
  local file_dir = vim.fn.fnamemodify(test_file_path, ':h')
  
  -- Try to reverse engineer source file name from test file patterns
  for _, pattern in ipairs(lang_config.test_file_patterns) do
    -- Convert glob pattern to regex and try to match
    local regex_pattern = pattern:gsub("%*", ".*"):gsub("%.%*", ".*")
    
    -- Simple pattern matching for common cases
    if file_name:match("test_(.+)%.") then
      local base_name = file_name:match("test_(.+)%.")
      local ext = file_name:match("%.(.+)$")
      local source_file = file_dir .. "/" .. base_name .. "." .. ext
      
      if vim.fn.filereadable(source_file) == 1 then
        return source_file
      end
    elseif file_name:match("(.+)_test%.") then
      local base_name = file_name:match("(.+)_test%.")
      local ext = file_name:match("%.(.+)$")
      local source_file = file_dir .. "/" .. base_name .. "." .. ext
      
      if vim.fn.filereadable(source_file) == 1 then
        return source_file
      end
    elseif file_name:match("(.+)%.test%.") then
      local base_name = file_name:match("(.+)%.test%.")
      local ext = file_name:match("%.([^.]+)$")
      local source_file = file_dir .. "/" .. base_name .. "." .. ext
      
      if vim.fn.filereadable(source_file) == 1 then
        return source_file
      end
    end
  end
  
  return nil
end

---Get test file for source file
---@param source_file_path string Source file path
---@return string? Test file path or nil
function M.get_test_file(source_file_path)
  local filetype = vim.filetype.match({ filename = source_file_path })
  local lang_config = config.get_language_config(filetype or "")
  
  if not lang_config or not lang_config.test_file_patterns then
    return nil
  end
  
  local file_name = vim.fn.fnamemodify(source_file_path, ':t')
  local file_dir = vim.fn.fnamemodify(source_file_path, ':h')
  local base_name = vim.fn.fnamemodify(source_file_path, ':t:r')
  local ext = vim.fn.fnamemodify(source_file_path, ':e')
  
  -- Try common test file naming patterns
  local test_patterns = {
    "test_" .. file_name,          -- test_file.ext
    base_name .. "_test." .. ext,   -- file_test.ext
    base_name .. ".test." .. ext,   -- file.test.ext
  }
  
  for _, test_pattern in ipairs(test_patterns) do
    local test_file = file_dir .. "/" .. test_pattern
    if vim.fn.filereadable(test_file) == 1 then
      return test_file
    end
  end
  
  -- Try looking in common test directories
  local test_dirs = { "test", "tests", "__tests__", "spec" }
  for _, test_dir in ipairs(test_dirs) do
    local test_dir_path = file_dir .. "/" .. test_dir
    if vim.fn.isdirectory(test_dir_path) == 1 then
      for _, test_pattern in ipairs(test_patterns) do
        local test_file = test_dir_path .. "/" .. test_pattern
        if vim.fn.filereadable(test_file) == 1 then
          return test_file
        end
      end
    end
  end
  
  return nil
end

---Check if file is a test file
---@param file_path string File path
---@return boolean
function M.is_test_file(file_path)
  local filetype = vim.filetype.match({ filename = file_path })
  local lang_config = config.get_language_config(filetype or "")
  
  if not lang_config or not lang_config.test_file_patterns then
    return false
  end
  
  local file_name = vim.fn.fnamemodify(file_path, ':t')
  
  for _, pattern in ipairs(lang_config.test_file_patterns) do
    -- Convert glob pattern to Lua pattern
    local lua_pattern = pattern:gsub("%*%*", ".-"):gsub("%*", "[^/]*"):gsub("%?", ".")
    
    if file_name:match(lua_pattern) then
      return true
    end
  end
  
  return false
end

return M