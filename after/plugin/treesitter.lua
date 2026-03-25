require'nvim-treesitter.configs'.setup {

	ensure_installed = {"java", "earthfile", "c","rust", "bash", "python", "lua","javascript", "html", "vim", "vimdoc", "query" },
	sync_install = true,
	auto_install = true,

	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	}

}
