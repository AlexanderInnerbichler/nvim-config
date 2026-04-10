-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    vim.api.nvim_echo({ { "Press any key to exit...", "ErrorMsg" } }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("alex")

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "vesper" } },
  checker = { enabled = false },
})

vim.cmd([[colorscheme vesper]])
vim.cmd([[tnoremap <Esc> <C-\><C-n>]])
vim.opt.termguicolors = true
