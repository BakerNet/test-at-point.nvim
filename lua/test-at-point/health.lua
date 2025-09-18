---@class TestAtPointHealth
local M = {}

local utils = require('test-at-point.utils')

---Check plugin health using proper Neovim health API
M.check = function()
  vim.health.start("test-at-point.nvim")

  -- Check Neovim version
  local min_version = "0.8.0"
  if utils.check_neovim_version(min_version) then
    local version = utils.get_neovim_version()
    vim.health.ok("Neovim version: " .. version.string .. " (>= " .. min_version .. ")")
  else
    local version = utils.get_neovim_version()
    vim.health.error(
      "Neovim version: " .. version.string .. " (< " .. min_version .. ")",
      { "Please upgrade to Neovim " .. min_version .. " or later" }
    )
  end

  -- Check configuration
  local config_ok, config = pcall(require, 'test-at-point.config')
  if config_ok then
    vim.health.ok("Configuration loaded successfully")
    local lang_count = 0
    for _ in pairs(config.get_config().languages or {}) do
      lang_count = lang_count + 1
    end
    vim.health.info("Configured languages: " .. lang_count)
  else
    vim.health.error("Failed to load configuration")
  end

  -- Check optional dependencies
  vim.health.start("Optional Dependencies")
  
  local has_treesitter = pcall(require, 'nvim-treesitter')
  if has_treesitter then
    vim.health.ok("nvim-treesitter available (enhanced test detection)")
  else
    vim.health.info("nvim-treesitter not found (will use pattern-based detection)")
  end

  -- Check test tools
  vim.health.start("Test Tools")
  
  local tools = { 
    { cmd = "go", desc = "Go test runner" },
    { cmd = "python", desc = "Python interpreter" },
    { cmd = "python3", desc = "Python 3 interpreter" },
    { cmd = "cargo", desc = "Rust package manager" },
    { cmd = "node", desc = "Node.js runtime" },
    { cmd = "npm", desc = "Node package manager" }
  }
  
  local available = {}
  local missing = {}
  
  for _, tool in ipairs(tools) do
    if utils.command_exists(tool.cmd) then
      table.insert(available, tool.desc)
    else
      table.insert(missing, tool.desc)
    end
  end

  if #available > 0 then
    vim.health.ok("Available tools: " .. table.concat(available, ", "))
  end
  
  if #missing > 0 then
    vim.health.warn(
      "Missing tools: " .. table.concat(missing, ", "),
      { "Install missing tools for full language support" }
    )
  end

  if #available == 0 then
    vim.health.error(
      "No test tools found",
      { "Please install at least one supported test tool (go, python, cargo, node)" }
    )
  end
end

return M

