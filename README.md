# test-at-point.nvim

A Neovim plugin for easily running unit tests at cursor position.

## 🙏 Acknowledgments

This plugin is inspired by and reimplements the functionality of the excellent [test-at-point](https://github.com/C-Hipple/test-at-point) Emacs package by Chris Hipple. While this is a complete rewrite for Neovim.

**Original Emacs Package**: https://github.com/C-Hipple/test-at-point  
**Original Author**: Chris Hipple

## 🚀 Development Status

Early WIP - You probably shouldn't use this yet

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "BakerNet/test-at-point.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter", -- Optional: for enhanced test detection
  }
  config = function()
    require("test-at-point").setup({
      -- Configuration options
    })
  end,
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:TestAtPoint` | Run test at cursor position |
| `:TestAtPointLast` | Re-run last test |
| `:TestAtPointDebug` | Run test in debug mode |
| `:TestAtPointSelect` | Add test to selection buffer |
| `:TestAtPointRunSelected` | Run all selected tests |
| `:TestAtPointClearSelected` | Clear test selection |
| `:TestAtPointSwitch` | Switch between source and test files |

## Supported Languages

- **Go**: Test functions, benchmarks, examples
- **Python**: pytest, unittest, async tests
- **Rust**: `#[test]`, `#[tokio::test]`, rstest
- **JavaScript/TypeScript**: Jest, Vitest, Mocha patterns

## Health Check

Run `:checkhealth test-at-point` to verify:
- Neovim version compatibility
- Plugin configuration
- Language tool availability
- Optional dependency status

## Configuration

<details>
<summary>Full Configuration Schema</summary>

```lua
{
  -- Global settings
  auto_save = true,                    -- Save buffers before running tests
  prefer_treesitter = true,            -- Prefer treesitter over patterns
  silent = false,                      -- Suppress informational messages
  
  -- Output configuration
  output = {
    mode = "quickfix",                 -- "quickfix" | "terminal" | "floating"
    terminal = {
      size = 0.3,                      -- Size as fraction or absolute
      position = "bottom",             -- "bottom" | "right" | "floating"
    },
    quickfix = {
      auto_open = true,                -- Auto-open on failures
      auto_close = false,              -- Auto-close on success
    }
  },
  
  -- Execution settings
  execution = {
    timeout = 30000,                   -- Timeout in milliseconds
    cwd_strategy = "project_root",     -- "current" | "project_root" | "file_dir"
  },
  
  -- Key mappings
  keymaps = {
    run_test = "<leader>tr",
    run_last = "<leader>tl",
    debug_test = "<leader>td",
    select_test = "<leader>ts",
  },
  
  -- Language-specific settings
  languages = {
    go = {
      patterns = { "^func (Test%w+)" },
      commands = { "go test -v -run ^%s$ ./..." },
      root_markers = { "go.mod" }
    }
    -- ... other languages
  }
}
```

</details>

