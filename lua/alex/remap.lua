vim.g.mapleader = " "

vim.api.nvim_set_keymap("n", "<leader>pf", ":Texplore<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>w", ":w<CR>", {})

local opts = { noremap = true, silent = true }
vim.api.nvim_set_keymap("n", "<leader>ö", "<cmd>lua vim.diagnostic.open_float()<CR>", opts)

local function JavaGoogleFormat()
	local current_file = vim.fn.expand("%:p")
	vim.cmd("!java -jar ~/.config/nvim/google-java-format-1.22.0-all-deps.jar -i " .. current_file)
end
vim.api.nvim_create_user_command("JavaGoogleFormat", JavaGoogleFormat, {})
vim.api.nvim_set_keymap("n", "<leader>jf", ":JavaGoogleFormat<CR>", { noremap = true, silent = true })

-- quickfix list remaps start with c
vim.api.nvim_set_keymap("n", "<leader>cn", ":cn<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>cN", ":cN<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>co", ":copen<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>cc", ":cclose<CR>", {})

-- quickererrer
vim.api.nvim_set_keymap("n", "<leader>l", ":lua QuickerNewThought()<CR> :lua QuickerSetAllMarks()<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>fl", ":lua QuickerSearchThoughts()<CR>", {})

-- claude hud
vim.api.nvim_set_keymap("n", "<leader>h", ":lua HudToggle()<CR>", {})

-- fugitive vim Git commands start with g
vim.api.nvim_set_keymap("n", "<leader>g", ":Git<CR>:resize<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>gs", ":Git status<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>gc", ":Git commit -a<CR>:resize<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>gd", ":Gdiff<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>gl", ":Git log --oneline <CR> :resize<CR>", {})

-- resize
vim.api.nvim_set_keymap("n", "<leader>rr", ":resize<CR>", {})

-- tab control starts with nothing
vim.api.nvim_set_keymap("n", "<leader>q", ":tabp<CR>", {})
vim.api.nvim_set_keymap("n", "<leader>e", ":tabn<CR>", {})

-- open underlying file in new tab
vim.api.nvim_set_keymap("n", "<leader>a", "<C-w>gf<CR>", { noremap = true, silent = true })

--clear search highlighting
vim.api.nvim_set_keymap("n", "<leader>o", ":nohlsearch<CR>", {})

-- avante
-- alot of the avante stuf is already defined
vim.api.nvim_set_keymap("n", "<leader>at", ":AvanteToggle<CR>", {})

-- neotest
vim.keymap.set("n", "<leader>na", "<cmd>Neotest attach<cr>", { desc = "Neotest - Run All Tests" })
vim.keymap.set("n", "<leader>nj", "<cmd>Neotest jump<cr>", { desc = "Neotest - Run File Tests" })
vim.keymap.set("n", "<leader>no", "<cmd>Neotest output-panel<cr>", { desc = "Neotest - Output Panel" })
vim.keymap.set("n", "<leader>ns", "<cmd>Neotest summary<cr>", { desc = "Neotest - Summary Panel" })
vim.keymap.set("n", "<leader>nr", "<cmd>Neotest run<cr>", { desc = "Neotest - Stop Running Tests" })


