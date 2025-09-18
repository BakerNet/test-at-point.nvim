---@class TestAtPointExecution
local M = {}

local utils = require('test-at-point.utils')
local config = require('test-at-point.config')

---Execute a test
---@param test_info table Test information
---@param opts? table Execution options
---@return table? Job object or nil
function M.run_test(test_info, opts)
  opts = opts or {}
  
  utils.log.info("Executing test: %s", test_info.name)
  
  -- Build command
  local cmd = M.build_command(test_info, opts)
  if not cmd then
    utils.log.error("Failed to build command for test: %s", test_info.name)
    return nil
  end
  
  utils.log.debug("Test command: %s", table.concat(cmd, " "))
  
  -- Execute command
  return M._execute_command(cmd, test_info, opts)
end

---Build test command
---@param test_info table Test information
---@param opts? table Build options
---@return string[]? Command array or nil
function M.build_command(test_info, opts)
  opts = opts or {}
  
  local lang_config = config.get_language_config(test_info.language)
  if not lang_config then
    utils.log.error("No configuration found for language: %s", test_info.language)
    return nil
  end
  
  -- Choose command templates based on mode
  local command_templates
  if opts.debug and lang_config.debug_commands then
    command_templates = lang_config.debug_commands
  elseif opts.coverage and lang_config.coverage_commands then
    command_templates = lang_config.coverage_commands
  else
    command_templates = lang_config.commands
  end
  
  if not command_templates or #command_templates == 0 then
    utils.log.error("No command templates configured for %s", test_info.language)
    return nil
  end
  
  -- Use first command template for now
  local template = command_templates[1]
  
  -- Build command string
  local cmd_str = M._format_command_template(template, test_info, opts)
  
  -- Split command into array
  return utils.split(cmd_str, " ")
end

---Format command template with test information
---@param template string Command template
---@param test_info table Test information
---@param opts table Options
---@return string Formatted command string
function M._format_command_template(template, test_info, opts)
  -- Simple string replacement (not using gsub patterns to avoid issues)
  local result = template
  result = result:gsub("%%s", test_info.name)
  result = result:gsub("%%f", utils.get_relative_path(test_info.file_path))
  result = result:gsub("%%F", test_info.file_path)
  result = result:gsub("%%d", vim.fn.fnamemodify(test_info.file_path, ':h'))
  result = result:gsub("%%n", vim.fn.fnamemodify(test_info.file_path, ':t:r'))
  result = result:gsub("%%e", vim.fn.fnamemodify(test_info.file_path, ':e'))
  
  return result
end

---Execute command asynchronously
---@param cmd string[] Command array
---@param test_info table Test information
---@param opts table Execution options
---@return table Job object
function M._execute_command(cmd, test_info, opts)
  local job = {
    cmd = cmd,
    test_info = test_info,
    opts = opts,
    running = true,
    output = {},
    errors = {},
    exit_code = nil,
    start_time = vim.loop.hrtime()
  }
  
  -- Determine working directory
  local cwd = M._get_working_directory(test_info, opts)
  
  -- Prepare execution options
  local exec_opts = {
    cwd = cwd,
    env = opts.env or {},
    timeout = opts.timeout or config.get_config().execution.timeout,
    text = true
  }
  
  -- For now, just show a placeholder message
  vim.notify(
    string.format("Would execute: %s (in %s)", table.concat(cmd, " "), cwd),
    vim.log.levels.INFO
  )
  
  -- Simulate async completion after a short delay
  vim.defer_fn(function()
    job.running = false
    job.exit_code = 0
    job.output = { "Test execution placeholder - not yet implemented" }
    
    -- Process results
    M._process_results(job)
  end, 100)
  
  return job
end

---Get working directory for test execution
---@param test_info table Test information
---@param opts table Execution options
---@return string Working directory path
function M._get_working_directory(test_info, opts)
  local cfg = config.get_config()
  local strategy = opts.cwd_strategy or cfg.execution.cwd_strategy
  
  if strategy == "current" then
    return vim.fn.getcwd()
  elseif strategy == "file_dir" then
    return vim.fn.fnamemodify(test_info.file_path, ':h')
  else -- "project_root"
    local lang_config = config.get_language_config(test_info.language)
    if lang_config and lang_config.root_markers then
      local project_root = utils.find_project_root(lang_config.root_markers, test_info.file_path)
      if project_root then
        return project_root
      end
    end
    
    -- Fallback to file directory
    return vim.fn.fnamemodify(test_info.file_path, ':h')
  end
end

---Process test execution results
---@param job table Job object
function M._process_results(job)
  utils.log.debug("Processing test results for: %s", job.test_info.name)
  
  local cfg = config.get_config()
  local output_mode = job.opts.output_mode or cfg.output.mode
  
  if output_mode == "quickfix" then
    M._handle_quickfix_output(job)
  elseif output_mode == "terminal" then
    M._handle_terminal_output(job)
  elseif output_mode == "floating" then
    M._handle_floating_output(job)
  end
end

---Handle quickfix output
---@param job table Job object
function M._handle_quickfix_output(job)
  utils.log.debug("Handling quickfix output (placeholder)")
  
  -- Placeholder - just show a message
  if job.exit_code == 0 then
    vim.notify("Test passed: " .. job.test_info.name, vim.log.levels.INFO)
  else
    vim.notify("Test failed: " .. job.test_info.name, vim.log.levels.ERROR)
  end
end

---Handle terminal output
---@param job table Job object
function M._handle_terminal_output(job)
  utils.log.debug("Handling terminal output (placeholder)")
  vim.notify("Terminal output not yet implemented", vim.log.levels.WARN)
end

---Handle floating window output
---@param job table Job object
function M._handle_floating_output(job)
  utils.log.debug("Handling floating window output (placeholder)")
  vim.notify("Floating window output not yet implemented", vim.log.levels.WARN)
end

---Stop a running job
---@param job table Job object
---@return boolean Success
function M.stop_job(job)
  if job and job.running then
    job.running = false
    job.exit_code = -1
    utils.log.info("Stopped test execution: %s", job.test_info.name)
    return true
  end
  return false
end

---Check if job is running
---@param job table Job object
---@return boolean
function M.is_job_running(job)
  return job and job.running or false
end

return M