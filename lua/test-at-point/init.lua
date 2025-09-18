---@class TestAtPoint
local M = {}

-- Store last test info for repeat functionality
M._last_test = nil
M._selected_tests = {}

---Setup the plugin
---@param config? table User configuration
function M.setup(config)
  require('test-at-point.config').setup(config)
end

---Run test at cursor position
---@param opts? string|table Execution options
---@return boolean success
function M.run_test_at_point(opts)
  -- Parse options if string
  if type(opts) == "string" then
    opts = { mode = opts }
  end
  opts = opts or {}
  
  -- Find test at cursor
  local test_info = require('test-at-point.detection').find_test_at_cursor()
  if not test_info then
    vim.notify("No test found at cursor position", vim.log.levels.WARN)
    return false
  end
  
  -- Store for repeat functionality
  M._last_test = test_info
  
  -- Execute the test
  return M._execute_test(test_info, opts)
end

---Re-run the last test
---@param opts? string|table Execution options
---@return boolean success
function M.run_last_test(opts)
  if not M._last_test then
    vim.notify("No previous test to run", vim.log.levels.WARN)
    return false
  end
  
  if type(opts) == "string" then
    opts = { mode = opts }
  end
  opts = opts or {}
  
  return M._execute_test(M._last_test, opts)
end

---Run test at cursor in debug mode
---@return boolean success
function M.debug_test_at_point()
  return M.run_test_at_point({ debug = true })
end

---Add test at cursor to selection buffer
---@return boolean success
function M.select_test_at_point()
  local test_info = require('test-at-point.detection').find_test_at_cursor()
  if not test_info then
    vim.notify("No test found at cursor position", vim.log.levels.WARN)
    return false
  end
  
  -- Check if already selected
  for _, selected in ipairs(M._selected_tests) do
    if selected.name == test_info.name and selected.file_path == test_info.file_path then
      vim.notify("Test already selected: " .. test_info.name, vim.log.levels.INFO)
      return true
    end
  end
  
  table.insert(M._selected_tests, test_info)
  vim.notify("Selected test: " .. test_info.name, vim.log.levels.INFO)
  
  -- Update selection buffer if it exists
  require('test-at-point.ui.selection').update_buffer(M._selected_tests)
  
  return true
end

---Run all selected tests
---@param opts? table Execution options
---@return boolean success
function M.run_selected_tests(opts)
  if #M._selected_tests == 0 then
    vim.notify("No tests selected", vim.log.levels.WARN)
    return false
  end
  
  opts = opts or {}
  
  -- Execute all selected tests
  for _, test_info in ipairs(M._selected_tests) do
    M._execute_test(test_info, opts)
  end
  
  return true
end

---Clear all selected tests
function M.clear_selected_tests()
  M._selected_tests = {}
  require('test-at-point.ui.selection').clear_buffer()
  vim.notify("Cleared selected tests", vim.log.levels.INFO)
end

---Get currently selected tests
---@return table[] Array of TestInfo objects
function M.get_selected_tests()
  return vim.deepcopy(M._selected_tests)
end

---Switch between source and test files
---@return boolean success
function M.switch_to_test_file()
  vim.notify("File switching not yet implemented", vim.log.levels.WARN)
  return false
end

---Find all tests in current file
---@param bufnr? number Buffer number
---@return table[] Array of TestInfo objects
function M.find_all_tests(bufnr)
  return require('test-at-point.detection').find_all_tests_in_file(bufnr)
end

---Register a new language
---@param filetype string
---@param config table Language configuration
function M.register_language(filetype, config)
  require('test-at-point.config').register_language(filetype, config)
end

---Execute a test
---@param test_info table Test information
---@param opts table Execution options
---@return boolean success
function M._execute_test(test_info, opts)
  opts = opts or {}
  
  -- Get configuration
  local config = require('test-at-point.config').get_config()
  
  -- Save buffers if configured
  if config.auto_save then
    vim.cmd('silent! wall')
  end
  
  -- Build and execute command
  local success, job = pcall(require('test-at-point.execution').run_test, test_info, opts)
  
  if not success then
    vim.notify("Failed to execute test: " .. tostring(job), vim.log.levels.ERROR)
    return false
  end
  
  if not config.silent then
    vim.notify("Running test: " .. test_info.name, vim.log.levels.INFO)
  end
  
  return true
end

return M