local function setup_hl()
  vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg",      { bg = "#252530" })
  vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg",      { bg = "#1e1e26" })
  vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg",      { bg = "#1a1a22" })
  vim.api.nvim_set_hl(0, "RenderMarkdownH4Bg",      { bg = "#1a1a22" })
  vim.api.nvim_set_hl(0, "RenderMarkdownH5Bg",      { bg = "#1a1a22" })
  vim.api.nvim_set_hl(0, "RenderMarkdownH6Bg",      { bg = "#1a1a22" })
  vim.api.nvim_set_hl(0, "RenderMarkdownCode",       { bg = "#1e1e26" })
  vim.api.nvim_set_hl(0, "RenderMarkdownCodeBorder", { bg = "#1e1e26" })
end

setup_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_hl })

require("render-markdown").setup({})
