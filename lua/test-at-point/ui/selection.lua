---@class TestAtPointSelection
local M = {}

local utils = require('test-at-point.utils')

-- Buffer name for test selection
local SELECTION_BUFFER_NAME = "*test-at-point-selections*"

---Update the selection buffer with current tests
---@param tests table[] Array of TestInfo objects
function M.update_buffer(tests)
  utils.log.debug("Updating selection buffer with %d tests", #tests)
  
  -- For now, just log the update - full implementation coming in Phase 4
  for i, test in ipairs(tests) do
    utils.log.debug("  %d. %s (%s)", i, test.name, utils.get_relative_path(test.file_path))
  end
end

---Clear the selection buffer
function M.clear_buffer()
  utils.log.debug("Clearing selection buffer (placeholder)")
  -- Placeholder implementation
end

---Get selection buffer
---@return number? Buffer number or nil
function M.get_buffer()
  utils.log.debug("Getting selection buffer (placeholder)")
  -- Placeholder implementation
  return nil
end

---Show selection buffer
function M.show_buffer()
  utils.log.debug("Showing selection buffer (placeholder)")
  vim.notify("Selection buffer UI not yet implemented", vim.log.levels.INFO)
end

---Hide selection buffer
function M.hide_buffer()
  utils.log.debug("Hiding selection buffer (placeholder)")
  -- Placeholder implementation
end

return M