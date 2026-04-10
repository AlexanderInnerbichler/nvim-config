local M = {}

-- ── authoritative heatmap constants ────────────────────────────────────────

local TIER_CHARS      = { " ", "░", "▒", "▓", "█", "󰵿" }
local TIER_THRESHOLDS = { 0, 1, 4, 10, 20, 35 }

M.HEAT_HLS     = { "GhHeat0", "GhHeat1", "GhHeat2", "GhHeat3", "GhHeat4", "GhHeat5" }
M.HEATMAP_WEEKS = 52

-- ── helpers ────────────────────────────────────────────────────────────────

local function separator(width)
  return "  " .. string.rep("─", (width or 60) - 2)
end

-- ── public API ─────────────────────────────────────────────────────────────

M.contribution_tier = function(count)
  if count == 0 then return 1 end
  for i = #TIER_THRESHOLDS, 2, -1 do
    if count >= TIER_THRESHOLDS[i] then return i end
  end
  return 2
end

M.render_heatmap = function(lines, hl_specs, contrib)
  if not contrib then return end
  local weeks = contrib.weeks
  if not weeks or #weeks == 0 then return end

  local day_labels = { "Mo", "  ", "We", "  ", "Fr", "  ", "Su" }
  local heatmap_lines = {}
  local heatmap_hl    = {}

  for day_idx = 1, 7 do
    local row_chars    = { "  ", day_labels[day_idx], " " }
    local col_positions = {}
    for _, week in ipairs(weeks) do
      local day = week[day_idx]
      if day then
        local tier = day.tier or 1
        local char = TIER_CHARS[tier]
        table.insert(col_positions, { col = #table.concat(row_chars), tier = tier })
        table.insert(row_chars, char)
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
        hl    = M.HEAT_HLS[cell.tier],
        line  = base_line + i - 1,
        col_s = cell.col,
        col_e = cell.col + 2,
      })
    end
  end

  local total_line = string.format("     %d contributions this year", contrib.total or 0)
  table.insert(lines, total_line)
  table.insert(hl_specs, { hl = "GhStats", line = #lines - 1, col_s = 0, col_e = #total_line })
  table.insert(lines, separator())
  table.insert(hl_specs, { hl = "GhSeparator", line = #lines - 1, col_s = 0, col_e = -1 })
end

return M
