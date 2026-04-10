-- after/plugin/conform.lua calls conform.setup() with all formatters —
-- it runs after plugin loading and overrides LazyVim's conform defaults.
return {
  { "stevearc/conform.nvim", opts = {} },
}
