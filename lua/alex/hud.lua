local main_color = "#7fc8f8"
local idle_color = "#555555"
local conflict_color = "#e5c07b"
local STALE_THRESHOLD = 600
local INSTANCE_STALE = 120
local COST_PER_MTOK = 1.50

local data_path = vim.fn.expand("~/.claude/hud.json")
local current_data_path = vim.fn.expand("~/.claude/hud.json")
local session_path = vim.fn.expand("~/.claude/hud_session.txt")
local velocity_path = vim.fn.expand("~/.claude/hud_velocity.txt")

local hud_buf = nil
local hud_win = nil
local timer = nil
local spin_timer = nil
local was_visible = false
local width = 40
local cached_data = nil
local session_start = nil

local instance_files = {}
local current_instance = 1
local max_tokens_seen = 0
local prev_confidence = {}   -- keyed by path
local peak_velocity = 0
local progress_history = {}  -- keyed by path
local token_histories = {}
local TOKEN_HISTORY_MAX = 30
local branch_cache = nil
local branch_ts = 0

local compact_mode = false
local daily_stats_path = vim.fn.expand("~/.claude/hud_daily.json")
local daily_stats = nil
local daily_stats_last_save = 0

local last_task = {}         -- keyed by path
local flash_until = {}       -- keyed by path, ms timestamp (vim.uv.now())
local last_progress_ts = {}  -- keyed by path, os.time() when progress last changed
local last_progress_val = {} -- keyed by path
local last_phase = {}        -- keyed by path
local daily_last_tokens = {} -- keyed by path, for token delta accumulation

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
  vim.api.nvim_set_hl(0, "HudFlash",       { bg = "#3d3010", fg = "#f0e080" })
  vim.api.nvim_set_hl(0, "HudWarn",        { fg = "#e5c07b", bg = "NONE" })
  vim.api.nvim_set_hl(0, "HudDaily",       { fg = "#616e88", bg = "NONE" })
end

local function scan_instances()
  local paths = vim.fn.glob(vim.fn.expand("~/.claude/hud-*.json"), false, true)
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
  local active_paths = { [data_path] = true }
  for _, inst in ipairs(instance_files) do active_paths[inst.path] = true end
  for p in pairs(token_histories) do
    if not active_paths[p] then token_histories[p] = nil end
  end
  for p in pairs(progress_history) do
    if not active_paths[p] then progress_history[p] = nil end
  end
  for p in pairs(prev_confidence) do
    if not active_paths[p] then prev_confidence[p] = nil end
  end
  for p in pairs(last_task) do
    if not active_paths[p] then last_task[p] = nil end
  end
  for p in pairs(flash_until) do
    if not active_paths[p] then flash_until[p] = nil end
  end
  for p in pairs(last_progress_ts) do
    if not active_paths[p] then last_progress_ts[p] = nil end
  end
  for p in pairs(last_progress_val) do
    if not active_paths[p] then last_progress_val[p] = nil end
  end
  for p in pairs(last_phase) do
    if not active_paths[p] then last_phase[p] = nil end
  end
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
  local lines = vim.fn.readfile(current_data_path)
  if not lines or #lines == 0 then
    return { task = "no active task", progress = 0, confidence = 0 }
  end
  local ok, t = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if ok and type(t) == "table" then return t end
  return { task = "no active task", progress = 0, confidence = 0 }
end

local function make_bar(value, max)
  local filled = math.floor((value / max) * 10)
  filled = math.max(0, math.min(10, filled))
  return string.rep("█", filled) .. string.rep("░", 10 - filled)
end

local spark_chars = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

local function make_sparkline(history, w)
  w = w or 20
  local slice = {}
  local start = math.max(1, #history - w + 1)
  for i = start, #history do table.insert(slice, history[i]) end
  while #slice < w do table.insert(slice, 1, 0) end
  local lo, hi = math.huge, -math.huge
  for _, v in ipairs(slice) do
    if v < lo then lo = v end
    if v > hi then hi = v end
  end
  local result = {}
  for _, v in ipairs(slice) do
    local idx = (hi == lo) and 1 or math.floor(((v - lo) / (hi - lo)) * 7) + 1
    table.insert(result, spark_chars[idx])
  end
  return table.concat(result)
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

local function get_eta(current_progress, hist)
  hist = hist or {}
  if current_progress >= 100 or #hist < 2 then return nil end
  local oldest = hist[1]
  local newest = hist[#hist]
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

local function today_str()
  return os.date("%Y-%m-%d")
end

local function load_daily_stats()
  local f = io.open(daily_stats_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    local ok, t = pcall(vim.fn.json_decode, content)
    if ok and type(t) == "table" and t.date == today_str() then
      return t
    end
  end
  return { date = today_str(), tasks = 0, tokens = 0 }
end

local function save_daily_stats()
  if not daily_stats then return end
  local f = io.open(daily_stats_path, "w")
  if f then
    f:write(vim.fn.json_encode(daily_stats))
    f:close()
  end
end

local function notify_done(task)
  io.write("\a")
  io.flush()
  if vim.fn.executable("notify-send") == 1 then
    vim.fn.jobstart({ "notify-send", "-t", "4000", "Claude Done", task })
  end
end

-- Returns lines and highlights: list of { line_idx_0based, hl_name }
local function render_lines(data, tok_history, path)
  local task       = data.task or "no active task"
  local progress   = data.progress or 0
  local confidence = data.confidence or 0
  local tokens     = data.tokens or 0
  local phase      = data.phase
  local note       = data.note or ""
  local highlights = {}

  -- Compact mode: single summary line
  if compact_mode then
    local bar_filled = math.max(0, math.min(5, math.floor(progress * 5 / 100)))
    local minibar = string.rep("█", bar_filled) .. string.rep("░", 5 - bar_filled)
    local phase_icon = (phase and phase_map[phase]) and (" " .. phase_map[phase].icon) or ""
    local task_max = 24
    if #task > task_max then task = task:sub(1, task_max - 1) .. "…" end
    local line = " " .. spin_chars[spin_idx] .. " " .. task
      .. string.format(" [%s]%3d%%%s", minibar, progress, phase_icon)
    local hls = {}
    if phase and phase_map[phase] then
      hls = { { 0, phase_map[phase].hl } }
    end
    return { line }, hls
  end

  local ph = path and progress_history[path] or {}
  local prog_vals = {}
  for _, e in ipairs(ph) do table.insert(prog_vals, e.progress) end
  local prog_spark = #prog_vals >= 2 and (" " .. make_sparkline(prog_vals, 8)) or ""

  -- Task line (index 0) — flash highlight when task just changed
  local task_line = " " .. spin_chars[spin_idx] .. " " .. task
  local lines = { task_line, "" }
  if path and flash_until[path] and vim.uv.now() < flash_until[path] then
    table.insert(highlights, { 0, "HudFlash" })
  end

  -- Progress line — stuck warning when exec stalls
  local stuck = phase == "exec" and progress < 100
    and path and last_progress_ts[path] ~= nil
    and (os.time() - last_progress_ts[path]) > 480
  local prog_line = string.format(" Progress   [%s] %d%%%s", make_bar(progress, 100), progress, prog_spark)
  if stuck then prog_line = prog_line .. "  ⚠ stuck?" end
  table.insert(lines, prog_line)
  if stuck then table.insert(highlights, { #lines - 1, "HudWarn" }) end

  local trend, trend_hl = "", nil
  local prev_conf = path and prev_confidence[path] or nil
  if prev_conf ~= nil then
    if confidence > prev_conf then
      trend, trend_hl = " ↑", "HudTrendUp"
    elseif confidence < prev_conf then
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
    local spark = make_sparkline(tok_history or {})
    table.insert(lines, string.format(" Tokens     %s %s", spark, display))
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

  local eta = get_eta(progress, path and progress_history[path] or {})
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

  if daily_stats and (daily_stats.tasks > 0 or daily_stats.tokens > 0) then
    local tok = daily_stats.tokens or 0
    local tok_disp = tok >= 1e6
      and string.format("%.1fM", tok / 1e6)
      or string.format("%dk", math.floor(tok / 1000))
    local cost = (tok / 1e6) * COST_PER_MTOK
    local cost_str = cost < 0.01 and "<$0.01" or string.format("$%.2f", cost)
    table.insert(lines, "")
    table.insert(lines, string.format(" today  %d tasks · %s tok · %s", daily_stats.tasks, tok_disp, cost_str))
    table.insert(highlights, { #lines - 1, "HudDaily" })
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

-- Compact 1-2 line summary for a non-selected instance
local function render_compact_instance(inst, idx)
  local now = os.time()
  local age = now - inst.mtime
  local raw = vim.fn.readfile(inst.path)
  if not raw or #raw == 0 then
    return { string.format(" · %d  (unreadable)", idx) }, {}
  end
  local ok, d = pcall(vim.fn.json_decode, table.concat(raw, "\n"))
  if not ok or type(d) ~= "table" then
    return { string.format(" · %d  (unreadable)", idx) }, {}
  end
  if age > STALE_THRESHOLD then
    local mins = math.floor(age / 60)
    return { string.format(" · %d  idle (%dm ago)", idx, mins) }, {}
  end
  local task = d.task or "no active task"
  local progress = d.progress or 0
  local note = d.note or ""
  local phase = d.phase
  local phase_icon = (phase and phase_map[phase]) and phase_map[phase].icon or " "
  -- truncate task to fit: width - " ⠋ X  " prefix (7 chars) leaves ~33
  local task_max = width - 7
  if #task > task_max then task = task:sub(1, task_max - 1) .. "…" end
  local line1 = string.format(" %s %d  %s", spin_chars[spin_idx], idx, task)
  -- 5-char mini bar (each char is 3 bytes, build directly to avoid sub on multibyte)
  local filled = math.max(0, math.min(5, math.floor(progress * 5 / 100)))
  local minibar = string.rep("█", filled) .. string.rep("░", 5 - filled)
  local note_max = width - 20
  if #note > note_max then note = note:sub(1, note_max - 1) .. "…" end
  local line2 = string.format("    [%s]%3d%% %s  %s", minibar, progress, phase_icon, note)
  local hls = {}
  if phase and phase_map[phase] then
    -- highlight the phase icon on line2 (index 1, 0-based)
    hls = { { 1, phase_map[phase].hl } }
  end
  return { line1, line2 }, hls
end

local function update_instance_state(path, data)
  if data.tokens and data.tokens > max_tokens_seen then
    max_tokens_seen = data.tokens
  end
  if data.tokens and data.tokens > 0 then
    if not token_histories[path] then token_histories[path] = {} end
    local hist = token_histories[path]
    table.insert(hist, data.tokens)
    if #hist > TOKEN_HISTORY_MAX then table.remove(hist, 1) end
  end
  if not progress_history[path] then progress_history[path] = {} end
  local ph = progress_history[path]
  local p = data.progress or 0
  local last_p = #ph > 0 and ph[#ph].progress or nil
  if last_p == nil or p ~= last_p then
    table.insert(ph, { ts = os.time(), progress = p })
    if #ph > 20 then table.remove(ph, 1) end
  end
  prev_confidence[path] = data.confidence or 0

  -- Task change flash
  local task = data.task or ""
  if last_task[path] ~= nil and last_task[path] ~= task then
    flash_until[path] = vim.uv.now() + 1200
  end
  last_task[path] = task

  -- Stuck detection: track last time progress changed
  local cur_p = data.progress or 0
  if last_progress_val[path] == nil or last_progress_val[path] ~= cur_p then
    last_progress_ts[path] = os.time()
    last_progress_val[path] = cur_p
  end

  -- Phase transition to done: notify + increment daily task count
  local cur_phase = data.phase
  local prev_ph = last_phase[path]
  if prev_ph ~= nil and prev_ph ~= "done" and cur_phase == "done" then
    notify_done(data.task or "task complete")
    if daily_stats then
      daily_stats.tasks = daily_stats.tasks + 1
      save_daily_stats()
    end
  end
  last_phase[path] = cur_phase

  -- Daily token accumulation
  if daily_stats and data.tokens and data.tokens > 0 then
    local prev_tok = daily_last_tokens[path] or 0
    if data.tokens > prev_tok then
      daily_stats.tokens = (daily_stats.tokens or 0) + (data.tokens - prev_tok)
    end
    daily_last_tokens[path] = data.tokens
  end
end

local function refresh()
  if not is_open() then return end

  scan_instances()
  local fresh = count_fresh_instances()

  local lines, highlights, w, fg
  if is_stale() and #instance_files == 0 then
    lines = { " · idle" }
    highlights = {}
    w = 12
    fg = idle_color
  else
    cached_data = load_data()
    update_instance_state(current_data_path, cached_data)
    local v = get_velocity()
    if v > peak_velocity then peak_velocity = v end
    lines, highlights = render_lines(cached_data, token_histories[current_data_path], current_data_path)
    w = width
    local cur_stuck = cached_data.phase == "exec"
      and (cached_data.progress or 0) < 100
      and last_progress_ts[current_data_path] ~= nil
      and (os.time() - last_progress_ts[current_data_path]) > 480
    fg = (fresh >= 2 or cur_stuck) and conflict_color or main_color

    -- Periodically persist daily stats
    local now_ts = os.time()
    if daily_stats and (now_ts - daily_stats_last_save) >= 60 then
      save_daily_stats()
      daily_stats_last_save = now_ts
    end

    -- Append compact rows for other instances when multiple are active
    if #instance_files > 1 then
      table.insert(lines, " " .. string.rep("─", width - 2))
      -- offset to adjust highlight indices
      local offset = #lines - 1
      for i, inst in ipairs(instance_files) do
        if i ~= current_instance then
          local clines, chls = render_compact_instance(inst, i)
          for _, cl in ipairs(clines) do table.insert(lines, cl) end
          for _, h in ipairs(chls) do
            table.insert(highlights, { h[1] + offset + 1, h[2] })
          end
          offset = offset + #clines
        end
      end
    end
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
  if compact_mode then
    local progress = cached_data.progress or 0
    local phase = cached_data.phase
    local bar_filled = math.max(0, math.min(5, math.floor(progress * 5 / 100)))
    local minibar = string.rep("█", bar_filled) .. string.rep("░", 5 - bar_filled)
    local phase_icon = (phase and phase_map[phase]) and (" " .. phase_map[phase].icon) or ""
    local task_max = 24
    if #task > task_max then task = task:sub(1, task_max - 1) .. "…" end
    local line = " " .. spin_chars[spin_idx] .. " " .. task
      .. string.format(" [%s]%3d%%%s", minibar, progress, phase_icon)
    vim.api.nvim_buf_set_lines(hud_buf, 0, 1, false, { line })
  else
    vim.api.nvim_buf_set_lines(hud_buf, 0, 1, false, { " " .. spin_chars[spin_idx] .. " " .. task })
  end
  vim.api.nvim_set_option_value("modifiable", false, { buf = hud_buf })
end

local function open()
  if is_open() then return end
  setup_highlights()
  if not session_start then init_session() end
  if not daily_stats then daily_stats = load_daily_stats() end

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
function HudRefresh() if is_open() then refresh() end end
function HudToggleCompact()
  compact_mode = not compact_mode
  if is_open() then refresh() end
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
  or #vim.fn.glob(vim.fn.expand("~/.claude/hud-*.json"), false, true) > 0
if any_hud then
  vim.defer_fn(open, 100)
end
