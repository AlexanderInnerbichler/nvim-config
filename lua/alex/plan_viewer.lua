local M = {}
local state = { buf = nil, win = nil, path = nil }

local plans_dir = vim.fn.expand("~/.claude/plans")

local function find_newest_plan()
	local files = vim.fn.glob(plans_dir .. "/*.md", false, true)
	if #files == 0 then return nil end
	table.sort(files, function(a, b)
		return vim.uv.fs_stat(a).mtime.sec > vim.uv.fs_stat(b).mtime.sec
	end)
	return files[1]
end

local function refresh()
	if not state.path or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
	local lines = vim.fn.readfile(state.path)
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
end

local function ensure_win()
	if state.win and vim.api.nvim_win_is_valid(state.win) then return end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].filetype = "markdown"
		vim.bo[state.buf].bufhidden = "hide"
	end
	vim.cmd("botright vsplit")
	state.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.win, state.buf)
	vim.wo[state.win].wrap = true
	vim.wo[state.win].linebreak = true
	vim.wo[state.win].number = false
	vim.wo[state.win].signcolumn = "no"
	vim.api.nvim_win_set_width(state.win, 70)
	vim.cmd("wincmd p")
end

local function open(path)
	state.path = path
	ensure_win()
	refresh()
end

local function close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, false)
		state.win = nil
	end
end

M.toggle = function()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		close()
	else
		local path = find_newest_plan()
		if path then
			open(path)
		else
			vim.notify("No plan files found", vim.log.levels.INFO)
		end
	end
end

M.setup = function()
	local watcher = vim.uv.new_fs_event()
	watcher:start(plans_dir, {}, function(err, fname, _events)
		if err or not fname or not fname:match("%.md$") then return end
		vim.schedule(function()
			local path = plans_dir .. "/" .. fname
			if state.win and vim.api.nvim_win_is_valid(state.win) then
				state.path = path
				refresh()
			else
				open(path)
			end
		end)
	end)
end

M.win_offset = function()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    return vim.api.nvim_win_get_width(state.win) + 1
  end
  return 0
end

return M
