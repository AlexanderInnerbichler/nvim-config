local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", function() builtin.find_files({ hidden = true }) end, {})
vim.keymap.set("n", "<leader>fg", function() builtin.live_grep({ additional_args = { "--hidden" } }) end, {})
vim.keymap.set("n", "<leader>fd", builtin.diagnostics, {})
vim.keymap.set("n", "<leader>fb", builtin.git_branches, {})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "TelescopeResults", "TelescopePreview" },
  callback = function(ev)
    vim.wo[vim.fn.bufwinid(ev.buf)].foldenable = false
  end,
})
