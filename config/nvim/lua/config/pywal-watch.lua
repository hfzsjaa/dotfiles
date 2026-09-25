local M = {}

local wal_cache = vim.fn.expand("~/.cache/wal/colors-wal.vim")
local watcher = vim.uv.new_fs_event()

local function reload_colors()
  vim.schedule(function()
    if vim.fn.filereadable(wal_cache) == 1 then
      pcall(vim.cmd, "colorscheme pywal") -- or: vim.cmd("source " .. wal_cache)
      vim.notify("Pywal colors reloaded", vim.log.levels.INFO)
    end
  end)
end

function M.start()
  local dir = vim.fn.fnamemodify(wal_cache, ":h") -- watch the directory, not just the file
  watcher:start(dir, {}, function(err, filename, events)
    if err then return end
    if filename == "colors-wal.vim" and events.change then
      reload_colors()
    end
  end)
end

return M
