---@class TestAtPointConfig
local M = {}

---@type table Default configuration
M.defaults = {
  -- Global settings
  auto_save = true,
  prefer_treesitter = true,
  silent = false,
  
  -- Output configuration
  output = {
    mode = "quickfix", -- "quickfix" | "terminal" | "floating"
    terminal = {
      size = 0.3,
      position = "bottom", -- "bottom" | "right" | "floating"
      close_on_exit = false,
      focus_on_open = true,
    },
    quickfix = {
      auto_open = true,
      auto_close = false,
      height = 10,
    },
    floating = {
      width = 0.8,
      height = 0.6,
      border = "rounded",
    }
  },
  
  -- Execution settings
  execution = {
    timeout = 30000,
    cwd_strategy = "project_root", -- "current" | "project_root" | "file_dir"
    env = {},
    parallel = false,
  },
  
  -- Language configurations
  languages = {
    go = {
      patterns = {
        "^func%s+(Test%w+)",
        "^func%s+(Benchmark%w+)",
        "^func%s+(Example%w+)"
      },
      commands = {
        "go test -v -run ^%s$ ./...",
        "go test -v -run ^%s$ ."
      },
      debug_commands = {
        "dlv test . -- -test.run ^%s$"
      },
      root_markers = { "go.mod", "go.sum" },
      test_file_patterns = { "*_test.go" },
    },
    
    python = {
      patterns = {
        "^def (test_%w+)",
        "^async def (test_%w+)",
        "^class (Test%w+)"
      },
      commands = {
        "pytest -xvs %s::%s",
        "python -m pytest -xvs %s::%s"
      },
      debug_commands = {
        "python -m debugpy --listen 5678 --wait-for-client -m pytest -xvs %s::%s"
      },
      root_markers = { "pytest.ini", "setup.py", "pyproject.toml" },
      test_file_patterns = { "test_*.py", "*_test.py" }
    },
    
    rust = {
      patterns = {
        "#%[test%]%s*fn (%w+)",
        "#%[tokio::test%]%s*async fn (%w+)"
      },
      commands = {
        "cargo test %s --",
        "cargo nextest run %s"
      },
      debug_commands = {
        "rust-gdb --args cargo test %s --"
      },
      root_markers = { "Cargo.toml" },
      test_file_patterns = { "src/**/*test*.rs", "tests/**/*.rs" }
    },
    
    javascript = {
      patterns = {
        "test%s*%(%s*['\"]([^'\"]+)['\"]",
        "it%s*%(%s*['\"]([^'\"]+)['\"]"
      },
      commands = {
        "npm test -- --testNamePattern='%s'",
        "jest --testNamePattern='%s'"
      },
      root_markers = { "package.json", "jest.config.js" },
      test_file_patterns = { "**/*.test.js", "**/*.spec.js" }
    },
    
    typescript = {
      patterns = {
        "test%s*%(%s*['\"]([^'\"]+)['\"]",
        "it%s*%(%s*['\"]([^'\"]+)['\"]"
      },
      commands = {
        "npm test -- --testNamePattern='%s'",
        "vitest run -t '%s'"
      },
      root_markers = { "package.json", "vitest.config.ts" },
      test_file_patterns = { "**/*.test.ts", "**/*.spec.ts" }
    }
  },
  
  -- Project-specific overrides
  projects = {},
  
  -- Key mappings (not set by default)
  keymaps = {
    run_test = "",
    run_last = "",
    debug_test = "",
    select_test = "",
    run_selected = "",
    clear_selected = "",
    switch_file = ""
  },
  
  -- Integration settings
  integrations = {
    telescope = true,
    lualine = true,
    which_key = true,
    coverage = {
      enabled = false,
      provider = "auto"
    }
  }
}

---@type table Current configuration
M._config = {}

---Deep merge two tables
---@param base table
---@param override table
---@return table
local function merge_config(base, override)
  local result = vim.deepcopy(base)
  
  for key, value in pairs(override) do
    if type(value) == "table" and type(result[key]) == "table" then
      result[key] = merge_config(result[key], value)
    else
      result[key] = value
    end
  end
  
  return result
end

---Validate configuration
---@param config table
---@return boolean, string?
local function validate_config(config)
  -- Basic type checking
  if type(config) ~= "table" then
    return false, "Configuration must be a table"
  end
  
  -- Validate output mode
  if config.output and config.output.mode then
    local valid_modes = { "quickfix", "terminal", "floating" }
    if not vim.tbl_contains(valid_modes, config.output.mode) then
      return false, "Invalid output mode: " .. config.output.mode
    end
  end
  
  -- Validate execution timeout
  if config.execution and config.execution.timeout then
    if type(config.execution.timeout) ~= "number" or config.execution.timeout <= 0 then
      return false, "Execution timeout must be a positive number"
    end
  end
  
  -- Validate language configurations
  if config.languages then
    for lang, lang_config in pairs(config.languages) do
      if type(lang_config) ~= "table" then
        return false, "Language configuration for " .. lang .. " must be a table"
      end
      
      if lang_config.patterns and type(lang_config.patterns) ~= "table" then
        return false, "Patterns for " .. lang .. " must be an array"
      end
      
      if lang_config.commands and type(lang_config.commands) ~= "table" then
        return false, "Commands for " .. lang .. " must be an array"
      end
    end
  end
  
  return true, nil
end

---Setup the plugin with user configuration
---@param config? table User configuration
function M.setup(config)
  config = config or {}
  
  -- Validate configuration
  local valid, err = validate_config(config)
  if not valid then
    vim.notify("test-at-point.nvim: " .. err, vim.log.levels.ERROR)
    return
  end
  
  -- Merge with defaults
  M._config = merge_config(M.defaults, config)
  
  -- Set up keymaps if provided
  if config.keymaps then
    M._setup_keymaps(M._config.keymaps)
  end
  
  -- Initialize project-specific config detection
  M._detect_project_config()
end

---Set up key mappings
---@param keymaps table
function M._setup_keymaps(keymaps)
  local opts = { noremap = true, silent = true }
  
  if keymaps.run_test and keymaps.run_test ~= "" then
    vim.keymap.set('n', keymaps.run_test, '<cmd>TestAtPoint<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Run test at point' }))
  end
  
  if keymaps.run_last and keymaps.run_last ~= "" then
    vim.keymap.set('n', keymaps.run_last, '<cmd>TestAtPointLast<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Run last test' }))
  end
  
  if keymaps.debug_test and keymaps.debug_test ~= "" then
    vim.keymap.set('n', keymaps.debug_test, '<cmd>TestAtPointDebug<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Debug test at point' }))
  end
  
  if keymaps.select_test and keymaps.select_test ~= "" then
    vim.keymap.set('n', keymaps.select_test, '<cmd>TestAtPointSelect<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Select test at point' }))
  end
  
  if keymaps.run_selected and keymaps.run_selected ~= "" then
    vim.keymap.set('n', keymaps.run_selected, '<cmd>TestAtPointRunSelected<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Run selected tests' }))
  end
  
  if keymaps.clear_selected and keymaps.clear_selected ~= "" then
    vim.keymap.set('n', keymaps.clear_selected, '<cmd>TestAtPointClearSelected<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Clear selected tests' }))
  end
  
  if keymaps.switch_file and keymaps.switch_file ~= "" then
    vim.keymap.set('n', keymaps.switch_file, '<cmd>TestAtPointSwitch<cr>', 
      vim.tbl_extend('force', opts, { desc = 'Switch test/source file' }))
  end
end

---Detect and load project-specific configuration
function M._detect_project_config()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ':t')
  
  -- Check if project has specific config
  if M._config.projects[project_name] then
    -- Merge project config with current config
    for lang, lang_config in pairs(M._config.projects[project_name]) do
      if M._config.languages[lang] then
        M._config.languages[lang] = merge_config(M._config.languages[lang], lang_config)
      end
    end
  end
end

---Get current configuration
---@return table
function M.get_config()
  if vim.tbl_isempty(M._config) then
    M._config = vim.deepcopy(M.defaults)
  end
  return M._config
end

---Get language-specific configuration
---@param filetype string
---@return table?
function M.get_language_config(filetype)
  local config = M.get_config()
  return config.languages[filetype]
end

---Get project-specific configuration
---@return table?
function M.get_project_config()
  local config = M.get_config()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ':t')
  return config.projects[project_name]
end

---Register a new language configuration
---@param filetype string
---@param lang_config table
function M.register_language(filetype, lang_config)
  local config = M.get_config()
  config.languages[filetype] = lang_config
end

---Update configuration at runtime
---@param updates table
function M.update_config(updates)
  local config = M.get_config()
  M._config = merge_config(config, updates)
end

return M