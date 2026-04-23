local M = {}
local DIARY_REPO = vim.fn.expand("~/thoughts")

local function sync_note(filepath)
  local fname = vim.fn.fnamemodify(filepath, ":t")
  local script = table.concat({
    "cd " .. vim.fn.shellescape(DIARY_REPO),
    "git add " .. vim.fn.shellescape(fname),
    "git diff --cached --quiet || git commit -m " .. vim.fn.shellescape("diary: " .. fname:gsub("%.note$", "")),
    "git push",
  }, " && ")
  vim.system({ "bash", "-c", script }, { detach = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify("diary sync failed: " .. (result.stderr or ""), vim.log.levels.WARN)
      end)
    end
  end)
end

function M.open_today()
  local today = os.date("%Y-%m-%d")
  local path  = DIARY_REPO .. "/" .. today .. ".note"
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

function M.setup()
  local augroup = vim.api.nvim_create_augroup("DiaryAutoSync", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group    = augroup,
    pattern  = DIARY_REPO .. "/*.note",
    callback = function(ev)
      sync_note(vim.api.nvim_buf_get_name(ev.buf))
    end,
  })
end

return M
