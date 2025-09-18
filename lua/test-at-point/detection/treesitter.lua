---@class TestAtPointTreesitter
local M = {}

local utils = require('test-at-point.utils')

---Find test using Treesitter
---@param bufnr number Buffer number
---@param line number Line number
---@param col number Column number
---@return table? TestInfo object or nil
function M.find_test(bufnr, line, col)
  utils.log.debug("Treesitter test detection not yet implemented")
  -- Placeholder - will be implemented in Phase 2
  return nil
end

---Find all tests using Treesitter
---@param bufnr number Buffer number
---@return table[] Array of TestInfo objects
function M.find_all_tests(bufnr)
  utils.log.debug("Treesitter bulk test detection not yet implemented")
  -- Placeholder - will be implemented in Phase 2
  return {}
end

---Get context using Treesitter
---@param bufnr number Buffer number
---@param line number Line number
---@return table? TestContext object or nil
function M.get_context(bufnr, line)
  utils.log.debug("Treesitter context detection not yet implemented")
  -- Placeholder - will be implemented in Phase 2
  return nil
end

return M