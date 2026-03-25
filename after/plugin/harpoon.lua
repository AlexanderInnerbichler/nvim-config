local harpoon = require("harpoon")

harpoon:setup({
	menu = {
		highlights = {},
	},
})
local conf = require("telescope.config").values
local function toggle_telescope(harpoon_files)
	local file_paths = {}
	for _, item in ipairs(harpoon_files.items) do
		table.insert(file_paths, item.value)
	end

	require("telescope.pickers")
		.new({}, {
			prompt_title = "Harpoon",
			finder = require("telescope.finders").new_table({
				results = file_paths,
			}),
			previewer = conf.file_previewer({}),
			sorter = conf.generic_sorter({}),
		})
		:find()
end

vim.keymap.set("n", "<leader>a", function()
	harpoon:list():add()
end)
--vim.keymap.set('n', '<leader>j', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
vim.keymap.set("n", "<leader>n", function()
	harpoon:list():next()
end)
vim.keymap.set("n", "<leader>m", function()
	harpoon:list():prev()
end)
vim.keymap.set("n", "<leader>d", function()
	harpoon:list():remove()
end)
vim.keymap.set("n", "<leader>hl", function()
	toggle_telescope(harpoon:list())
end, { desc = "Open harpoon window" })
vim.keymap.set("n", "<leader>h", function()
	harpoon.ui:toggle_quick_menu(harpoon:list())
end)
--vim.keymap.set('n', '<leader>n', require("harpoon.ui").nav_next, {})
--vim.keymap.set('n', '<leader>m', require("harpoon.ui").nav_prev, {})

-- colorscheme
--vim.cmd("highlight! HarpoonInactive guibg=NONE guifg=NONE")
--vim.cmd("highlight! HarpoonActive guibg=black guifg=white")
--vim.cmd("highlight! HarpoonNumberActive guibg=NONE guifg=NONE")
--vim.cmd("highlight! HarpoonNumberInactive guibg=NONE guifg=#7aa2f7")
--vim.cmd("highlight! TabLineFill guibg=NONE guifg=white")
