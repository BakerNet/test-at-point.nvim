-- test-at-point.nvim entry point
-- This file sets up the plugin commands and keymaps

if vim.g.loaded_test_at_point then
  return
end
vim.g.loaded_test_at_point = true

-- Check minimum Neovim version
if vim.fn.has('nvim-0.8') == 0 then
  vim.api.nvim_err_writeln('test-at-point.nvim requires Neovim 0.8 or later')
  return
end

-- Create user commands
vim.api.nvim_create_user_command('TestAtPoint', function(opts)
  require('test-at-point').run_test_at_point(opts.args)
end, {
  desc = 'Run test at cursor position',
  nargs = '?',
  complete = function()
    return { 'debug', 'coverage' }
  end
})

vim.api.nvim_create_user_command('TestAtPointLast', function(opts)
  require('test-at-point').run_last_test(opts.args)
end, {
  desc = 'Re-run the last test',
  nargs = '?'
})

vim.api.nvim_create_user_command('TestAtPointDebug', function()
  require('test-at-point').debug_test_at_point()
end, {
  desc = 'Run test at cursor in debug mode'
})

vim.api.nvim_create_user_command('TestAtPointSelect', function()
  require('test-at-point').select_test_at_point()
end, {
  desc = 'Add test at cursor to selection buffer'
})

vim.api.nvim_create_user_command('TestAtPointRunSelected', function()
  require('test-at-point').run_selected_tests()
end, {
  desc = 'Run all tests in selection buffer'
})

vim.api.nvim_create_user_command('TestAtPointClearSelected', function()
  require('test-at-point').clear_selected_tests()
end, {
  desc = 'Clear all tests from selection buffer'
})

vim.api.nvim_create_user_command('TestAtPointSwitch', function()
  require('test-at-point').switch_to_test_file()
end, {
  desc = 'Switch between source and test files'
})