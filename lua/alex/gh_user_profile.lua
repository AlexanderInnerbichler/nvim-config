local M = {}

-- ── constants (duplicated from github_dashboard.lua — 2 callers, below abstraction threshold) ──

local HEATMAP_WEEKS   = 26
local TIER_CHARS      = { " ", "░", "▒", "▓", "█" }
local TIER_THRESHOLDS = { 0, 1, 4, 10, 25 }
local HEAT_HLS        = { "GhHeat0", "GhHeat1", "GhHeat2", "GhHeat3", "GhHeat4" }

local ns = vim.api.nvim_create_namespace("GhUserProfile")

-- ── helpers ────────────────────────────────────────────────────────────────

local function contribution_tier(count)
  if count == 0 then return 1 end
  for i = #TIER_THRESHOLDS, 2, -1 do
    if count >= TIER_THRESHOLDS[i] then return i end
  end
  return 2
end

local function sl(s) return (s or ""):gsub("[\n\r]", " ") end

local function run_gh(args, callback)
  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(result.stderr or "gh error", nil)
        return
      end
      local ok, decoded = pcall(vim.fn.json_decode, result.stdout)
      if not ok then
        callback("json decode error: " .. tostring(decoded), nil)
        return
      end
      callback(nil, decoded)
    end)
  end)
end

-- ── fetch functions ────────────────────────────────────────────────────────

local function fetch_user_profile(username, callback)
  run_gh(
    { "gh", "api", "/users/" .. username,
      "--jq", "{login:.login,name:.name,bio:.bio,followers:.followers,following:.following,public_repos:.public_repos}" },
    callback
  )
end

local CONTRIB_QUERY_FMT = "{ user(login: \"%s\") { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { contributionCount date } } } } } }"

local function fetch_user_contributions(username, callback)
  local query = string.format(CONTRIB_QUERY_FMT, username)
  vim.system(
    { "gh", "api", "graphql", "-f", "query=" .. query },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          callback(result.stderr or "graphql error", nil)
          return
        end
        local ok, decoded = pcall(vim.fn.json_decode, result.stdout)
        if not ok then callback("json error", nil) return end
        local cal = ((((decoded or {}).data or {}).user or {}).contributionsCollection or {}).contributionCalendar
        if not cal then callback("no contribution data", nil) return end
        local weeks = {}
        local all_weeks = cal.weeks or {}
        local start = math.max(1, #all_weeks - HEATMAP_WEEKS + 1)
        for i = start, #all_weeks do
          local days = {}
          for _, d in ipairs(all_weeks[i].contributionDays or {}) do
            table.insert(days, {
              date  = d.date,
              count = d.contributionCount,
              tier  = contribution_tier(d.contributionCount),
            })
          end
          table.insert(weeks, days)
        end
        callback(nil, { total = cal.totalContributions, weeks = weeks })
      end)
    end
  )
end

-- ── rendering ─────────────────────────────────────────────────────────────

local function render_content(lines, hl_specs, username, profile, contrib, profile_err, contrib_err)
  -- header
  local header = "  @" .. username
  table.insert(lines, header)
  table.insert(hl_specs, { hl = "GhSection",  line = #lines - 1, col_s = 0,  col_e = 2 })
  table.insert(hl_specs, { hl = "GhUsername", line = #lines - 1, col_s = 2,  col_e = #header })

  -- profile stats
  if profile_err then
    local msg = "  ✗ " .. sl(profile_err)
    table.insert(lines, msg)
    table.insert(hl_specs, { hl = "GhError", line = #lines - 1, col_s = 0, col_e = #msg })
  elseif profile then
    local total = contrib and contrib.total or 0
    local stats = string.format(
      "  👥 %d followers · %d following · %d repos · %d contributions",
      profile.followers or 0, profile.following or 0, profile.public_repos or 0, total
    )
    table.insert(lines, stats)
    table.insert(hl_specs, { hl = "GhStats", line = #lines - 1, col_s = 0, col_e = #stats })
    if profile.bio and profile.bio ~= "" and profile.bio ~= vim.NIL then
      local bio = "  " .. profile.bio
      table.insert(lines, bio)
      table.insert(hl_specs, { hl = "GhStats", line = #lines - 1, col_s = 0, col_e = #bio })
    end
  end

  -- separator
  local sep = "  " .. string.rep("─", 58)
  table.insert(lines, sep)
  table.insert(hl_specs, { hl = "GhSeparator", line = #lines - 1, col_s = 0, col_e = -1 })

  -- heatmap
  if contrib_err then
    local msg = "  ✗ contributions unavailable"
    table.insert(lines, msg)
    table.insert(hl_specs, { hl = "GhError", line = #lines - 1, col_s = 0, col_e = #msg })
    return
  end
  if not contrib or not contrib.weeks or #contrib.weeks == 0 then return end

  local day_labels = { "Mo", "  ", "We", "  ", "Fr", "  ", "Su" }
  local heatmap_lines = {}
  local heatmap_hl    = {}

  for day_idx = 1, 7 do
    local row_chars    = { "  ", day_labels[day_idx], " " }
    local col_positions = {}
    for _, week in ipairs(contrib.weeks) do
      local day = week[day_idx]
      if day then
        local tier = day.tier or 1
        table.insert(col_positions, { col = #table.concat(row_chars), tier = tier })
        table.insert(row_chars, TIER_CHARS[tier] .. " ")
      else
        table.insert(row_chars, "  ")
      end
    end
    table.insert(heatmap_lines, table.concat(row_chars))
    table.insert(heatmap_hl, col_positions)
  end

  local base_line = #lines
  for i, row in ipairs(heatmap_lines) do
    table.insert(lines, row)
    for _, cell in ipairs(heatmap_hl[i] or {}) do
      table.insert(hl_specs, {
        hl    = HEAT_HLS[cell.tier],
        line  = base_line + i - 1,
        col_s = cell.col,
        col_e = cell.col + 2,
      })
    end
  end

  local total_line = string.format("     %d contributions this year", contrib.total or 0)
  table.insert(lines, total_line)
  table.insert(hl_specs, { hl = "GhStats", line = #lines - 1, col_s = 0, col_e = #total_line })
end

-- ── popup ─────────────────────────────────────────────────────────────────

M.open = function(username)
  -- create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype    = "nofile"
  vim.bo[buf].bufhidden  = "wipe"
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype   = "text"

  local ui     = vim.api.nvim_list_uis()[1] or { width = 180, height = 50 }
  local width  = math.floor(ui.width  * 0.80)
  local height = math.floor(ui.height * 0.70)
  local row    = math.floor((ui.height - height) / 2)
  local col    = math.floor((ui.width  - width)  / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative   = "editor",
    width      = width,
    height     = height,
    row        = row,
    col        = col,
    style      = "minimal",
    border     = "rounded",
    title      = " @" .. username .. " ",
    title_pos  = "center",
    footer     = " q close ",
    footer_pos = "center",
  })
  vim.wo[win].number         = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn     = "no"
  vim.wo[win].cursorline     = true
  vim.wo[win].wrap           = false

  -- show loading state immediately
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "", "  Loading @" .. username .. "…", "" })
  vim.bo[buf].modifiable = false

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, false)
    end
  end

  local function bmap(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  bmap("q",     close)
  bmap("<Esc>", close)

  -- fan-out async fetches
  local pending     = 2
  local profile_res = nil
  local contrib_res = nil
  local profile_err = nil
  local contrib_err = nil

  local function render_and_apply()
    local lines, hl_specs = {}, {}
    table.insert(lines, "")
    render_content(lines, hl_specs, username, profile_res, contrib_res, profile_err, contrib_err)
    table.insert(lines, "")

    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, spec in ipairs(hl_specs) do
      vim.api.nvim_buf_add_highlight(buf, ns, spec.hl, spec.line,
        spec.col_s, spec.col_e == -1 and -1 or spec.col_e)
    end
  end

  local function done()
    pending = pending - 1
    if pending == 0 then render_and_apply() end
  end

  fetch_user_profile(username, function(err, data)
    profile_err = err
    profile_res = data
    done()
  end)

  fetch_user_contributions(username, function(err, data)
    contrib_err = err
    contrib_res = data
    done()
  end)
end

return M
