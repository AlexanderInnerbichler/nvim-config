local main_color = "#7fc8f8"
local idle_color = "#555555"
local STALE_THRESHOLD = 30
local data_path = vim.fn.expand("~/.claude/hud.lua")
local session_path = vim.fn.expand("~/.claude/hud_session.txt")

local hud_buf = nil
local hud_win = nil
local timer = nil
local spin_timer = nil
local was_visible = false
local width = 36
local cached_data = nil
local session_start = nil

local spin_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spin_idx = 1

local ns = vim.api.nvim_create_namespace("HudHighlights")

local phase_map = {
  study = { icon = "◎", label = "Studying",  hl = "HudPhaseStudy" },
  plan  = { icon = "◈", label = "Planning",  hl = "HudPhasePlan"  },
  exec  = { icon = "▶", label = "Executing", hl = "HudPhaseExec"  },
  done  = { icon = "✓", label = "Done",      hl = "HudPhaseDone"  },
}

local function setup_highlights()
  vim.api.nvim_set_hl(0, "HudFloat",       { bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudTokenSafe",   { fg = "#7fc8f8", bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudTokenWarn",   { fg = "#f0c060", bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudTokenDanger", { fg = "#f07070", bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudPhaseStudy",  { fg = "#b48ead", bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "HudPhasePlan",   { fg = "#ebcb8b", bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "HudPhaseExec",   { fg = "#a3be8c", bg = "NONE", bold = true })
  vim.api.nvim_set_hl(0, "HudPhaseDone",   { fg = "#88c0d0", bg = "NONE", bold = true })
end

local function is_stale()
  local stat = vim.uv.fs_stat(data_path)
  if not stat then return true end
  return (os.time() - stat.mtime.sec) > STALE_THRESHOLD
end

local function load_data()
  local ok, t = pcall(dofile, data_path)
  if ok and type(t) == "table" then return t end
  return { task = "no active task", progress = 0, confidence = 0 }
end

local function make_bar(value, max)
  local filled = math.floor((value / max) * 10)
  filled = math.max(0, math.min(10, filled))
  return string.rep("█", filled) .. string.rep("░", 10 - filled)
end

local function init_session()
  local f = io.open(session_path, "r")
  if f then
    local ts = tonumber(f:read("*l"))
    f:close()
    if ts then
      local ts_d = os.date("*t", ts)
      local now_d = os.date("*t")
      if ts_d.year == now_d.year and ts_d.yday == now_d.yday then
        session_start = ts
        return
      end
    end
  end
  session_start = os.time()
  local wf = io.open(session_path, "w")
  if wf then
    wf:write(tostring(session_start))
    wf:close()
  end
end

local function format_elapsed()
  if not session_start then return nil end
  local elapsed = math.max(0, os.time() - session_start)
  local m = math.floor(elapsed / 60)
  local s = elapsed % 60
  if m >= 60 then
    return string.format("%dh %02dm", math.floor(m / 60), m % 60)
  end
  return string.format("%dm %02ds", m, s)
end

-- Returns lines and highlights: list of { line_idx_0based, hl_name }
local function render_lines(data)
  local task       = data.task or "no active task"
  local progress   = data.progress or 0
  local confidence = data.confidence or 0
  local tokens     = data.tokens or 0
  local phase      = data.phase
  local note       = data.note or ""
  local highlights = {}

  local lines = {
    " " .. spin_chars[spin_idx] .. " " .. task,
    "",
    string.format(" Progress   [%s] %d%%",   make_bar(progress, 100), progress),
    string.format(" Confidence [%s] %d/10",  make_bar(confidence, 10), confidence),
  }

  if tokens > 0 then
    local display = tokens >= 1000
      and string.format("~%.1fk", tokens / 1000)
      or tostring(tokens)
    table.insert(lines, string.format(" Tokens     [%s] %s", make_bar(tokens, 200000), display))
    local hl = tokens > 150000 and "HudTokenDanger"
            or tokens > 100000 and "HudTokenWarn"
            or "HudTokenSafe"
    table.insert(highlights, { #lines - 1, hl })
  end

  local elapsed = format_elapsed()
  if elapsed then
    table.insert(lines, string.format(" Session    %s", elapsed))
  end

  if phase and phase_map[phase] then
    local p = phase_map[phase]
    table.insert(lines, "")
    table.insert(lines, string.format(" %s %s", p.icon, p.label))
    table.insert(highlights, { #lines - 1, p.hl })
  elseif note ~= "" then
    table.insert(lines, "")
    table.insert(lines, " " .. note)
  end

  return lines, highlights
end

local function is_open()
  return hud_win ~= nil and vim.api.nvim_win_is_valid(hud_win)
end

local function apply_highlights(highlights)
  vim.api.nvim_buf_clear_namespace(hud_buf, ns, 0, -1)
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(hud_buf, ns, h[2], h[1], 0, -1)
  end
end

local function set_lines(lines)
  vim.api.nvim_set_option_value("modifiable", true, { buf = hud_buf })
  vim.api.nvim_buf_set_lines(hud_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })
end

local function refresh()
  if not is_open() then return end
  local lines, highlights, w, fg
  if is_stale() then
    lines = { " · idle" }
    highlights = {}
    w = 12
    fg = idle_color
  else
    cached_data = load_data()
    lines, highlights = render_lines(cached_data)
    w = width
    fg = main_color
  end
  local ui = vim.api.nvim_list_uis()[1]
  vim.api.nvim_set_hl(0, "HudBorder", { bg = "NONE", fg = fg })
  vim.api.nvim_set_hl(0, "HudTitle",  { fg = fg, bg = "NONE", bold = true })
  vim.api.nvim_win_set_config(hud_win, {
    relative = "editor",
    row = 1,
    col = ui.width - w - 2,
    width = w,
    height = #lines,
  })
  set_lines(lines)
  apply_highlights(highlights)
end

local function tick_spinner()
  if not is_open() or is_stale() or not cached_data then return end
  spin_idx = (spin_idx % #spin_chars) + 1
  local task = cached_data.task or "no active task"
  vim.api.nvim_set_option_value("modifiable", true, { buf = hud_buf })
  vim.api.nvim_buf_set_lines(hud_buf, 0, 1, false, { " " .. spin_chars[spin_idx] .. " " .. task })
  vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })
end

local function open()
  if is_open() then return end
  setup_highlights()
  if not session_start then init_session() end

  if not (hud_buf and vim.api.nvim_buf_is_valid(hud_buf)) then
    hud_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = hud_buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })
  end

  local ui = vim.api.nvim_list_uis()[1]
  hud_win = vim.api.nvim_open_win(hud_buf, false, {
    relative = "editor",
    row = 1,
    col = ui.width - width - 2,
    width = width,
    height = 1,
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

  refresh()

  if not timer then
    timer = vim.uv.new_timer()
    timer:start(3000, 3000, vim.schedule_wrap(refresh))
  end
  if not spin_timer then
    spin_timer = vim.uv.new_timer()
    spin_timer:start(100, 100, vim.schedule_wrap(tick_spinner))
  end
end

local function close()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
  if spin_timer then
    spin_timer:stop()
    spin_timer:close()
    spin_timer = nil
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
