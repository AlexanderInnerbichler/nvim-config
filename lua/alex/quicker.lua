local main_color = "#7fc8f8"
local namespace = vim.api.nvim_create_namespace("QuickerSymbols")

local TAGS = {
  { prefix = "#todo", icon = "󰄱 ", hl = "QuickerTodo",     color = "#f59e0b" },
  { prefix = "#bug",  icon = " ",  hl = "QuickerBug",      color = "#f87171" },
  { prefix = "#q",    icon = " ",  hl = "QuickerQuestion", color = "#a78bfa" },
}
local DEFAULT_ICON = " "
local DEFAULT_HL   = "QuickerBorder"

local function get_tag(text)
  if not text then return nil end
  for _, t in ipairs(TAGS) do
    if text:sub(1, #t.prefix) == t.prefix then return t end
  end
  return nil
end

local function setup_tag_highlights()
  for _, t in ipairs(TAGS) do
    vim.api.nvim_set_hl(0, t.hl, { fg = t.color, bg = "NONE" })
  end
end
setup_tag_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_tag_highlights })

local function set_status_symbol(bufnr, line, text)
  local tag  = get_tag(text)
  local icon = tag and tag.icon or DEFAULT_ICON
  local hl   = tag and tag.hl   or DEFAULT_HL
  vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
    virt_text = { { icon, hl } },
    virt_text_pos = "inline",
    right_gravity = true,
  })
end

local THOUGHTS_REPO = vim.fn.expand("~/thoughts")

local function _db_path(filedir)
  return filedir .. "/.thoughts.alex.lua"
end

local function _load(filedir)
  local p = _db_path(filedir)
  local ok, t = pcall(dofile, p)
  return (ok and type(t) == 'table') and t or {}
end

local function _sync_to_repo(filedir)
  local src = _db_path(filedir)
  if vim.fn.filereadable(src) == 0 then return end

  -- derive project name from the directory (last two path components)
  local parts = vim.split(filedir, "/", { plain = true })
  local project = (#parts >= 2)
    and (parts[#parts - 1] .. "_" .. parts[#parts])
    or parts[#parts]
  project = project:gsub("[^%w_%-]", "_")

  local dest_dir = THOUGHTS_REPO .. "/" .. project
  local dest     = dest_dir .. "/thoughts.lua"

  local script = table.concat({
    "mkdir -p " .. vim.fn.shellescape(dest_dir),
    "cp " .. vim.fn.shellescape(src) .. " " .. vim.fn.shellescape(dest),
    "cd " .. vim.fn.shellescape(THOUGHTS_REPO),
    "git add " .. vim.fn.shellescape(project .. "/thoughts.lua"),
    "git diff --cached --quiet || git commit -m " .. vim.fn.shellescape("sync: " .. project),
    "git push",
  }, " && ")

  vim.system({ "bash", "-c", script }, { detach = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify("thoughts sync failed: " .. (result.stderr or ""), vim.log.levels.WARN)
      end)
    end
  end)
end

local function _save(t, filedir)
  local path = _db_path(filedir)
  local f, err = io.open(path, 'w')
  if not f then
    vim.notify("thoughts: could not save — " .. (err or "unknown error"), vim.log.levels.ERROR)
    return
  end
  f:write('return ' .. vim.inspect(t))
  f:close()
  _sync_to_repo(filedir)
end

local function delete_line(filedir, filename, linenumber)
  local db = _load(filedir)
  db[filename] = db[filename] or {}
  local list = db[filename]
  for i, e in ipairs(list) do
    if e.linenumber == linenumber then
      table.remove(list, i)
      break
    end
  end
  _save(db, filedir)
end

local function save_line(filedir, filename, linenumber, text, timestamp)
  local db = _load(filedir)
  db[filename] = db[filename] or {}
  local list = db[filename]
  local found = nil
  for _, e in ipairs(list) do
    if e.linenumber == linenumber then
      found = e
      break
    end
  end
  if found then
    found.text = text
    found.timestamp = timestamp
  else
    table.insert(list, { linenumber = linenumber, text = text, timestamp = timestamp })
  end
  _save(db, filedir)
  vim.notify("thought saved")
end

local function fetch_line(filedir, filename, linenumber)
  local db = _load(filedir)
  db[filename] = db[filename] or {}
  local list = db[filename]
  for _, e in ipairs(list) do
    if e.linenumber == linenumber then
      return e
    end
  end
  local timestamp = os.date("!%H:%M:%S %d-%m-%Y ")
  return { linenumber = linenumber, text = nil, timestamp = timestamp }
end

local function refresh_marks(buf, filedir, filename)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  local db = _load(filedir)
  db[filename] = db[filename] or {}
  for _, e in ipairs(db[filename]) do
    set_status_symbol(buf, e.linenumber - 1, e.text)
  end
end

function QuickerDeleteAllMarks()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
end

function QuickerSetAllMarks()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
  local filedir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p:h')
  local db = _load(filedir)
  db[filename] = db[filename] or {}
  for _, e in ipairs(db[filename]) do
    set_status_symbol(buf, e.linenumber - 1, e.text)
  end
end

function QuickerUpdateMarks()
  QuickerDeleteAllMarks()
  QuickerSetAllMarks()
end

-- Sync extmark positions back to DB to fix line drift after edits
local function sync_marks_to_db(buf)
  local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t')
  local filedir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':p:h')
  if filename == '' then return end

  local marks = vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {})
  if #marks == 0 then return end

  local db = _load(filedir)
  local list = db[filename]
  if not list or #list == 0 or #marks ~= #list then return end

  local mark_lines = {}
  for _, m in ipairs(marks) do
    table.insert(mark_lines, m[2] + 1)
  end
  table.sort(mark_lines)
  table.sort(list, function(a, b) return a.linenumber < b.linenumber end)

  local changed = false
  for i, e in ipairs(list) do
    if e.linenumber ~= mark_lines[i] then
      e.linenumber = mark_lines[i]
      changed = true
    end
  end

  if changed then
    _save(db, filedir)
  end
end

local function save_thoughts_lua(float_buf, filedir, filename, linenumber)
  local text = table.concat(vim.api.nvim_buf_get_lines(float_buf, 0, -1, false), "\n")
  if text == "" then
    delete_line(filedir, filename, linenumber)
    vim.notify("thought cleared")
    return
  end
  local timestamp = os.date("!%H:%M:%S %d-%m-%Y ")
  save_line(filedir, filename, linenumber, text, timestamp)
end

function QuickerNewThought()
  local main_win = vim.api.nvim_get_current_win()
  local main_buf = vim.api.nvim_win_get_buf(main_win)
  local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(main_buf), ':t')
  local filedir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(main_buf), ':p:h')
  local linenumber = vim.api.nvim_win_get_cursor(main_win)[1]

  if filename == '' then
    vim.notify("thoughts: save the file first", vim.log.levels.WARN)
    return
  end

  if vim.fn.isdirectory(filedir) == 0 then
    vim.notify("thoughts: directory does not exist — " .. filedir, vim.log.levels.WARN)
    return
  end

  local line = fetch_line(filedir, filename, linenumber)
  local buf = vim.api.nvim_create_buf(false, true)

  local is_new = not line.text
  if not is_new then
    local lines = vim.split(line.text, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  local ui = vim.api.nvim_list_uis()[1]
  local width, height = 40, 10
  local tag = get_tag(line.text)
  local tag_label = tag and (" · " .. tag.prefix) or ""
  local title = " " .. tostring(linenumber) .. "   THOUGHT" .. tag_label .. " "
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((ui.height - height) / 4),
    col = math.floor((ui.width - width - 5)),
    title = title,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded"
  })
  vim.api.nvim_set_option_value("number", true, { win = win })
  vim.api.nvim_set_option_value("winhl", "Normal:QuickerFloat,FloatBorder:QuickerBorder,FloatTitle:QuickerFloatTitle", { win = win })
  vim.api.nvim_set_hl(0, "QuickerFloat", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "QuickerBorder", { bg = "NONE", fg = main_color })
  vim.api.nvim_set_hl(0, "QuickerFloatTitle", { fg = main_color, bg = "NONE", bold = true })

  local function close()
    save_thoughts_lua(buf, filedir, filename, linenumber)
    refresh_marks(main_buf, filedir, filename)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function delete_and_close()
    delete_line(filedir, filename, linenumber)
    refresh_marks(main_buf, filedir, filename)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.notify("thought deleted")
  end

  vim.keymap.set("n", "q", close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf })
  vim.keymap.set("n", "D", delete_and_close, { buffer = buf })

  if is_new then
    vim.cmd("startinsert")
  end
end

function QuickerSearchThoughts(tag_filter)
  local ok_p, pickers = pcall(require, 'telescope.pickers')
  local ok_f, finders = pcall(require, 'telescope.finders')
  local ok_c, conf_mod = pcall(require, 'telescope.config')
  local ok_a, actions = pcall(require, 'telescope.actions')
  local ok_s, action_state = pcall(require, 'telescope.actions.state')
  if not (ok_p and ok_f and ok_c and ok_a and ok_s) then
    vim.notify("Telescope not available", vim.log.levels.WARN)
    return
  end
  local conf = conf_mod.values

  local cwd = vim.fn.getcwd()
  local thoughts_files = vim.fn.globpath(cwd, '**/.thoughts.alex.lua', false, true)

  local entries = {}
  for _, path in ipairs(thoughts_files) do
    local ok_db, db = pcall(dofile, path)
    if ok_db and type(db) == 'table' then
      local dir = vim.fn.fnamemodify(path, ':h')
      for fname, list in pairs(db) do
        for _, e in ipairs(list) do
          if not tag_filter or e.text:sub(1, #tag_filter) == tag_filter then
            local t = get_tag(e.text)
            local icon = t and t.icon or DEFAULT_ICON
            local short = e.text:gsub('\n', ' ')
            table.insert(entries, {
              display = string.format("%s%s:%d  %s", icon, fname, e.linenumber, short),
              ordinal = string.format("%s:%d  %s", fname, e.linenumber, short),
              filename = dir .. '/' .. fname,
              lnum = e.linenumber,
            })
          end
        end
      end
    end
  end

  local title = tag_filter and ("Thoughts · " .. tag_filter) or "Thoughts"
  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table({
      results = entries,
      entry_maker = function(e)
        return {
          value    = e,
          display  = e.display,
          ordinal  = e.ordinal,
          filename = e.filename,
          lnum     = e.lnum,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = conf.grep_previewer({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local sel = action_state.get_selected_entry()
        if sel then
          vim.cmd('edit ' .. vim.fn.fnameescape(sel.filename))
          vim.api.nvim_win_set_cursor(0, { sel.lnum, 0 })
        end
      end)
      return true
    end,
  }):find()
end

-- Auto-restore marks when a file is loaded into a buffer
local augroup = vim.api.nvim_create_augroup("QuickerThoughts", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(ev)
    local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ':t')
    local filedir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ':p:h')
    if filename == '' then return end
    local db = _load(filedir)
    local list = db[filename]
    if not list then return end
    for _, e in ipairs(list) do
      set_status_symbol(ev.buf, e.linenumber - 1, e.text)
    end
  end,
})

-- Sync stored line numbers to actual extmark positions after each write
vim.api.nvim_create_autocmd("BufWritePost", {
  group = augroup,
  callback = function(ev)
    sync_marks_to_db(ev.buf)
  end,
})
