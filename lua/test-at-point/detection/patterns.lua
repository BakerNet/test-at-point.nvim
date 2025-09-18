---@class TestAtPointPatterns
local M = {}

local utils = require('test-at-point.utils')

---Find test function using pattern matching
---@param bufnr number Buffer number
---@param line number Line number to start search from
---@param patterns string[] Array of regex patterns
---@return table? TestInfo object or nil
function M.find_test(bufnr, line, patterns)
  if not patterns or #patterns == 0 then
    return nil
  end
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line, false)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  
  -- Search backwards from current line
  for i = line, 1, -1 do
    local line_text = lines[i] or ""
    
    for _, pattern in ipairs(patterns) do
      local match = line_text:match(pattern)
      if match then
        utils.log.debug("Found test using pattern '%s' at line %d: %s", pattern, i, match)
        
        return {
          name = match,
          file_path = file_path,
          line = i,
          column = 1,
          language = filetype,
          context = M._get_context(bufnr, i, filetype)
        }
      end
    end
  end
  
  return nil
end

---Find all tests in buffer using patterns
---@param bufnr number Buffer number
---@param patterns string[] Array of regex patterns
---@return table[] Array of TestInfo objects
function M.find_all_tests(bufnr, patterns)
  if not patterns or #patterns == 0 then
    return {}
  end
  
  local tests = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  
  for i, line_text in ipairs(lines) do
    for _, pattern in ipairs(patterns) do
      local match = line_text:match(pattern)
      if match then
        table.insert(tests, {
          name = match,
          file_path = file_path,
          line = i,
          column = 1,
          language = filetype,
          context = M._get_context(bufnr, i, filetype)
        })
        break -- Don't match multiple patterns on same line
      end
    end
  end
  
  utils.log.debug("Found %d tests using patterns in %s", #tests, vim.fn.fnamemodify(file_path, ':t'))
  return tests
end

---Get test context information
---@param bufnr number Buffer number
---@param test_line number Line number of test
---@param filetype string File type
---@return table? TestContext object or nil
function M._get_context(bufnr, test_line, filetype)
  -- Language-specific context detection
  if filetype == "javascript" or filetype == "typescript" then
    return M._get_js_context(bufnr, test_line)
  elseif filetype == "python" then
    return M._get_python_context(bufnr, test_line)
  elseif filetype == "go" then
    return M._get_go_context(bufnr, test_line)
  elseif filetype == "rust" then
    return M._get_rust_context(bufnr, test_line)
  end
  
  return nil
end

---Get JavaScript/TypeScript test context (describe blocks)
---@param bufnr number Buffer number
---@param test_line number Test line number
---@return table? TestContext object
function M._get_js_context(bufnr, test_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, test_line, false)
  local context_stack = {}
  local indent_stack = {}
  
  -- Patterns for describe blocks
  local describe_patterns = {
    "describe%s*%(%s*['\"]([^'\"]+)['\"]",
    "describe%.skip%s*%(%s*['\"]([^'\"]+)['\"]",
    "describe%.only%s*%(%s*['\"]([^'\"]+)['\"]",
    "context%s*%(%s*['\"]([^'\"]+)['\"]"
  }
  
  for i = 1, #lines do
    local line = lines[i]
    local indent = line:match("^(%s*)")
    
    -- Check for describe blocks
    for _, pattern in ipairs(describe_patterns) do
      local match = line:match(pattern)
      if match then
        -- Remove contexts with deeper or equal indentation
        while #indent_stack > 0 and #indent <= #indent_stack[#indent_stack] do
          table.remove(context_stack)
          table.remove(indent_stack)
        end
        
        table.insert(context_stack, match)
        table.insert(indent_stack, indent)
        break
      end
    end
  end
  
  if #context_stack > 0 then
    return {
      describe = table.concat(context_stack, " > "),
      nested_level = #context_stack - 1,
      file_scope = false
    }
  end
  
  return nil
end

---Get Python test context (test classes)
---@param bufnr number Buffer number
---@param test_line number Test line number
---@return table? TestContext object
function M._get_python_context(bufnr, test_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, test_line, false)
  local class_name = nil
  
  -- Look for class definition before the test
  for i = test_line - 1, 1, -1 do
    local line = lines[i]
    local match = line:match("^class%s+(Test%w+)")
    if match then
      class_name = match
      break
    end
    
    -- Stop if we hit another function or class at same level
    if line:match("^class%s+") or line:match("^def%s+") then
      break
    end
  end
  
  if class_name then
    return {
      describe = class_name,
      nested_level = 1,
      file_scope = false
    }
  end
  
  return nil
end

---Get Go test context
---@param bufnr number Buffer number
---@param test_line number Test line number
---@return table? TestContext object
function M._get_go_context(bufnr, test_line)
  -- Go tests are typically at package level
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local package_name = vim.fn.fnamemodify(file_path, ':h:t')
  
  return {
    describe = "package " .. package_name,
    nested_level = 0,
    file_scope = true
  }
end

---Get Rust test context
---@param bufnr number Buffer number
---@param test_line number Test line number
---@return table? TestContext object
function M._get_rust_context(bufnr, test_line)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, test_line, false)
  local context_stack = {}
  local indent_stack = {}
  
  -- Look for mod blocks
  for i = 1, test_line - 1 do
    local line = lines[i]
    local indent = line:match("^(%s*)")
    
    -- Check for module blocks
    local mod_match = line:match("^%s*mod%s+(%w+)%s*{")
    if mod_match then
      -- Remove contexts with deeper or equal indentation
      while #indent_stack > 0 and #indent <= #indent_stack[#indent_stack] do
        table.remove(context_stack)
        table.remove(indent_stack)
      end
      
      table.insert(context_stack, mod_match)
      table.insert(indent_stack, indent)
    end
    
    -- Check for closing braces that might end modules
    if line:match("^%s*}%s*$") and #context_stack > 0 then
      if #indent <= #indent_stack[#indent_stack] then
        table.remove(context_stack)
        table.remove(indent_stack)
      end
    end
  end
  
  if #context_stack > 0 then
    return {
      describe = table.concat(context_stack, "::"),
      nested_level = #context_stack - 1,
      file_scope = false
    }
  end
  
  -- Default to file-level context
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local file_name = vim.fn.fnamemodify(file_path, ':t:r')
  
  return {
    describe = file_name,
    nested_level = 0,
    file_scope = true
  }
end

---Validate regex patterns
---@param patterns string[] Array of patterns to validate
---@return boolean, string? valid, error_message
function M.validate_patterns(patterns)
  if type(patterns) ~= "table" then
    return false, "Patterns must be an array"
  end
  
  for i, pattern in ipairs(patterns) do
    if type(pattern) ~= "string" then
      return false, string.format("Pattern %d must be a string", i)
    end
    
    -- Test pattern validity
    local ok, err = pcall(string.match, "test string", pattern)
    if not ok then
      return false, string.format("Invalid regex pattern %d: %s", i, err)
    end
  end
  
  return true, nil
end

---Get language-specific test patterns
---@param filetype string File type
---@return string[] Array of patterns
function M.get_builtin_patterns(filetype)
  local builtin_patterns = {
    go = {
      "^func%s+(Test%w+)",
      "^func%s+(Benchmark%w+)", 
      "^func%s+(Example%w+)",
      "^func%s+(Fuzz%w+)"
    },
    
    python = {
      "^%s*def%s+(test_%w+)",
      "^%s*async%s+def%s+(test_%w+)",
      "^%s*class%s+(Test%w+)"
    },
    
    rust = {
      "#%[test%]%s*fn%s+(%w+)",
      "#%[tokio::test%]%s*async%s+fn%s+(%w+)",
      "#%[rstest%]%s*fn%s+(%w+)"
    },
    
    javascript = {
      "test%s*%(%s*['\"]([^'\"]+)['\"]",
      "it%s*%(%s*['\"]([^'\"]+)['\"]",
      "describe%s*%(%s*['\"]([^'\"]+)['\"]"
    },
    
    typescript = {
      "test%s*%(%s*['\"]([^'\"]+)['\"]",
      "it%s*%(%s*['\"]([^'\"]+)['\"]",
      "describe%s*%(%s*['\"]([^'\"]+)['\"]"
    }
  }
  
  return builtin_patterns[filetype] or {}
end

return M