-- after/plugin/feline.lua calls lualine.setup() — force eager load.
-- after/plugin/render-markdown.lua calls render-markdown.setup() — force eager load.
return {
  { "nvim-lualine/lualine.nvim", lazy = false },
  { "MeanderingProgrammer/render-markdown.nvim", lazy = false, dependencies = { "nvim-treesitter/nvim-treesitter" } },
  { "MunifTanjim/nui.nvim" },
}
