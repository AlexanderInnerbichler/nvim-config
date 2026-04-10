-- LazyVim bundles mason, mason-lspconfig, nvim-lspconfig with sensible defaults.
-- Default LSP keymaps (K, gd, gr, etc.) are provided by LazyVim automatically.
-- after/plugin/roselyn.lua handles roslyn setup.
-- after/plugin/mason.lua calls mason.setup() — force eager load so it's available.
return {
  { "seblyng/roslyn.nvim" },
  { "williamboman/mason.nvim", lazy = false },
}
