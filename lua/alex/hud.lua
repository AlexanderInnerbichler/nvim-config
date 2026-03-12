local main_color = "#7fc8f8"
local data_path = vim.fn.expand("~/.claude/hud.lua")

local hud_buf = nil
local hud_win = nil
local timer = nil
local was_visible = false
local width = 36

local function load_data()
  local ok, t = pcall(dofile, data_path)
  if ok and type(t) == 'table' then return t end
  return { task = "no active task", progress = 0, confidence = 0, note = "" }
end

local function make_bar(value, max)
  local filled = math.floor((value / max) * 10)
  filled = math.max(0, math.min(10, filled))
  return string.rep("█", filled) .. string.rep("░", 10 - filled)
end

local function render_lines(data)
  local task = data.task or "no active task"
  local progress = data.progress or 0
  local confidence = data.confidence or 0
  local note = data.note or ""

  local lines = {
    " " .. task,
    "",
    string.format(" Progress   [%s] %d%%", make_bar(progress, 100), progress),
    string.format(" Confidence [%s] %d/10", make_bar(confidence, 10), confidence),
  }
  if note ~= "" then
    table.insert(lines, "")
    table.insert(lines, " " .. note)
  end
  return lines
end

local function is_open()
  return hud_win ~= nil and vim.api.nvim_win_is_valid(hud_win)
end

local function refresh()
  if not is_open() then return end
  local data = load_data()
  local lines = render_lines(data)
  vim.api.nvim_set_option_value("modifiable", true, { buf = hud_buf })
  vim.api.nvim_buf_set_lines(hud_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })
  vim.api.nvim_win_set_config(hud_win, { height = #lines })
end

local function open()
  if is_open() then return end

  if not (hud_buf and vim.api.nvim_buf_is_valid(hud_buf)) then
    hud_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = hud_buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })
  end

  local data = load_data()
  local lines = render_lines(data)
  local ui = vim.api.nvim_list_uis()[1]

  hud_win = vim.api.nvim_open_win(hud_buf, false, {
    relative = "editor",
    row = 1,
    col = ui.width - width - 2,
    width = width,
    height = #lines,
    style = "minimal",
    border = "rounded",
    title = " claude ",
    focusable = false,
    zindex = 10,
  })

  vim.api.nvim_set_option_value(
    "winhl",
    "Normal:HudFloat,FloatBorder:HudBorder,FloatTitle:HudTitle",
    { win = hud_win }
  )
  vim.api.nvim_set_hl(0, "HudFloat", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudBorder", { bg = "NONE", fg = main_color })
  vim.api.nvim_set_hl(0, "HudTitle", { fg = main_color, bg = "NONE", bold = true })

  vim.api.nvim_set_option_value("modifiable", true, { buf = hud_buf })
  vim.api.nvim_buf_set_lines(hud_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })

  if not timer then
    timer = vim.uv.new_timer()
    timer:start(3000, 3000, vim.schedule_wrap(refresh))
  end
end

local function close()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  if is_open() then
    vim.api.nvim_win_close(hud_win, true)
    hud_win = nil
  end
end

function HudOpen() open() end
function HudClose() close() end
function HudToggle()
  if is_open() then close() else open() end
end

local augroup = vim.api.nvim_create_augroup("ClaudeHud", { clear = true })

vim.api.nvim_create_autocmd("InsertEnter", {
  group = augroup,
  callback = function()
    was_visible = is_open()
    if was_visible then
      vim.api.nvim_win_close(hud_win, true)
      hud_win = nil
    end
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = augroup,
  callback = function()
    if was_visible then open() end
  end,
})

if vim.fn.filereadable(data_path) == 1 then
  vim.defer_fn(open, 100)
end
