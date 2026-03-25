local main_color = "#7fc8f8"
local idle_color = "#555555"
local conflict_color = "#e5c07b"
local STALE_THRESHOLD = 600
local INSTANCE_STALE = 120
local COST_PER_MTOK = 1.50

local data_path = vim.fn.expand("~/.claude/hud.lua")
local current_data_path = vim.fn.expand("~/.claude/hud.lua")
local session_path = vim.fn.expand("~/.claude/hud_session.txt")
local velocity_path = vim.fn.expand("~/.claude/hud_velocity.txt")

local hud_buf = nil
local hud_win = nil
local timer = nil
local spin_timer = nil
local was_visible = false
local width = 36
local cached_data = nil
local session_start = nil

local instance_files = {}
local current_instance = 1
local max_tokens_seen = 0
local prev_confidence = nil
local peak_velocity = 0
local progress_history = {}
local branch_cache = nil
local branch_ts = 0

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
  vim.api.nvim_set_hl(0, "HudTrendUp",     { fg = "#a3be8c", bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudTrendDown",   { fg = "#f07070", bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudTrendFlat",   { fg = "#555555", bg = "NONE" })
end

local function scan_instances()
  local paths = vim.fn.glob(vim.fn.expand("~/.claude/hud-*.lua"), false, true)
  if vim.fn.filereadable(data_path) == 1 then
    table.insert(paths, data_path)
  end
  local now = os.time()
  local active = {}
  for _, p in ipairs(paths) do
    local stat = vim.uv.fs_stat(p)
    if stat and (now - stat.mtime.sec) <= INSTANCE_STALE then
      table.insert(active, { path = p, mtime = stat.mtime.sec })
    end
  end
  table.sort(active, function(a, b) return a.mtime > b.mtime end)
  instance_files = active
  current_instance = math.min(current_instance, math.max(1, #instance_files))
  current_data_path = #instance_files > 0 and instance_files[current_instance].path or data_path
end

local function count_fresh_instances()
  local now = os.time()
  local fresh = 0
  for _, inst in ipairs(instance_files) do
    if (now - inst.mtime) <= STALE_THRESHOLD then fresh = fresh + 1 end
  end
  return fresh
end

local function is_stale()
  local stat = vim.uv.fs_stat(current_data_path)
  if not stat then return true end
  return (os.time() - stat.mtime.sec) > STALE_THRESHOLD
end

local function load_data()
  local ok, t = pcall(dofile, current_data_path)
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

local function get_velocity()
  local f = io.open(velocity_path, "r")
  if not f then return 0 end
  local now = os.time()
  local count = 0
  for line in f:lines() do
    local ts = tonumber(line)
    if ts and (now - ts) <= 60 then count = count + 1 end
  end
  f:close()
  return count
end

local function get_total_tools()
  local f = io.open(velocity_path, "r")
  if not f then return 0 end
  local count = 0
  for _ in f:lines() do count = count + 1 end
  f:close()
  return count
end

local function get_branch()
  local now = os.time()
  if branch_cache ~= nil and (now - branch_ts) < 10 then
    return branch_cache
  end
  local b = vim.fn.system("git -C " .. vim.fn.getcwd() .. " branch --show-current 2>/dev/null"):gsub("\n", "")
  if b == "" or b:find("fatal") then b = nil end
  branch_cache = b
  branch_ts = now
  return b
end

local function get_eta(current_progress)
  if current_progress >= 100 or #progress_history < 2 then return nil end
  local oldest = progress_history[1]
  local newest = progress_history[#progress_history]
  local dt = newest.ts - oldest.ts
  local dp = newest.progress - oldest.progress
  if dt <= 0 or dp <= 0 then return nil end
  local rate = dp / dt
  local remaining = (100 - current_progress) / rate
  if remaining <= 0 or remaining > 7200 then return nil end
  local m = math.floor(remaining / 60)
  local s = math.floor(remaining % 60)
  if m >= 60 then
    return string.format("~%dh %dm", math.floor(m / 60), m % 60)
  elseif m > 0 then
    return string.format("~%dm", m)
  else
    return string.format("~%ds", s)
  end
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
    string.format(" Progress   [%s] %d%%", make_bar(progress, 100), progress),
  }

  local trend, trend_hl = "", nil
  if prev_confidence ~= nil then
    if confidence > prev_confidence then
      trend, trend_hl = " ↑", "HudTrendUp"
    elseif confidence < prev_confidence then
      trend, trend_hl = " ↓", "HudTrendDown"
    else
      trend, trend_hl = " →", "HudTrendFlat"
    end
  end
  table.insert(lines, string.format(" Confidence [%s] %d/10%s", make_bar(confidence, 10), confidence, trend))
  if trend_hl then
    table.insert(highlights, { #lines - 1, trend_hl })
  end

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

  if max_tokens_seen > 0 then
    local cost = (max_tokens_seen / 1e6) * COST_PER_MTOK
    local cost_str = cost < 0.01 and "<$0.01" or string.format("~$%.2f", cost)
    table.insert(lines, string.format(" Cost       %s", cost_str))
  end

  local velocity = get_velocity()
  if velocity > 0 then
    if peak_velocity > velocity then
      table.insert(lines, string.format(" Velocity   %d/min  pk:%d", velocity, peak_velocity))
    else
      table.insert(lines, string.format(" Velocity   %d/min", velocity))
    end
  end

  local total_tools = get_total_tools()
  if total_tools > 0 then
    table.insert(lines, string.format(" Tools      %d total", total_tools))
  end

  local elapsed = format_elapsed()
  if elapsed then
    table.insert(lines, string.format(" Session    %s", elapsed))
  end

  local eta = get_eta(progress)
  if eta then
    table.insert(lines, string.format(" ETA        %s", eta))
  end

  local branch = get_branch()
  if branch then
    table.insert(lines, string.format(" Branch     %s", branch))
  end

  if phase and phase_map[phase] then
    local p = phase_map[phase]
    table.insert(lines, "")
    table.insert(lines, string.format(" %s %s", p.icon, p.label))
    table.insert(highlights, { #lines - 1, p.hl })
    if note ~= "" then
      table.insert(lines, "  ↳ " .. note)
    end
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

  scan_instances()
  local fresh = count_fresh_instances()

  local lines, highlights, w, fg
  if is_stale() then
    lines = { " · idle" }
    highlights = {}
    w = 12
    fg = idle_color
  else
    cached_data = load_data()
    if cached_data.tokens and cached_data.tokens > max_tokens_seen then
      max_tokens_seen = cached_data.tokens
    end
    local p = cached_data.progress or 0
    local last_p = #progress_history > 0 and progress_history[#progress_history].progress or nil
    if last_p == nil or p ~= last_p then
      table.insert(progress_history, { ts = os.time(), progress = p })
      if #progress_history > 20 then table.remove(progress_history, 1) end
    end
    local v = get_velocity()
    if v > peak_velocity then peak_velocity = v end
    lines, highlights = render_lines(cached_data)
    prev_confidence = cached_data.confidence or 0
    w = width
    fg = fresh >= 2 and conflict_color or main_color
  end

  local title
  if #instance_files <= 1 then
    title = " claude "
  else
    title = string.format(" claude %d/%d ", current_instance, #instance_files)
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
    title = title,
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

function HudNextInstance()
  scan_instances()
  if #instance_files == 0 then return end
  current_instance = (current_instance % #instance_files) + 1
  current_data_path = instance_files[current_instance].path
  refresh()
end

function HudPrevInstance()
  scan_instances()
  if #instance_files == 0 then return end
  current_instance = ((current_instance - 2) % #instance_files) + 1
  current_data_path = instance_files[current_instance].path
  refresh()
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

local any_hud = vim.fn.filereadable(data_path) == 1
  or #vim.fn.glob(vim.fn.expand("~/.claude/hud-*.lua"), false, true) > 0
if any_hud then
  vim.defer_fn(open, 100)
end
