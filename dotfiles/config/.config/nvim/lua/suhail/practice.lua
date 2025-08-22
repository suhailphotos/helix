-- lua/suhail/practice.lua
local practice_active = false

-- load hardtime and enable it once the :Hardtime command exists
local function enable_hardtime_with_retry()
  require("lazy").load({ plugins = { "hardtime.nvim" } })
  local tries = 0
  local function attempt()
    if vim.fn.exists(":Hardtime") == 2 then
      vim.cmd("Hardtime enable")
      practice_active = true
    elseif tries < 20 then
      tries = tries + 1
      vim.defer_fn(attempt, 20)  -- retry for ~400ms total
    else
      vim.notify("Practice: failed to enable Hardtime (command missing)", vim.log.levels.ERROR)
    end
  end
  attempt()
end

vim.api.nvim_create_user_command("PracticeOn", function()
  enable_hardtime_with_retry()
end, { force = true })

vim.api.nvim_create_user_command("PracticeOff", function()
  if vim.fn.exists(":Hardtime") == 2 then
    vim.cmd("Hardtime disable")
  end
  practice_active = false
end, { force = true })

vim.api.nvim_create_user_command("PracticeToggle", function()
  if practice_active then
    vim.cmd("PracticeOff")
  else
    enable_hardtime_with_retry()
  end
end, { force = true })

vim.api.nvim_create_user_command("Practice", function()
  enable_hardtime_with_retry()
  -- start the game shortly after enabling to avoid races
  vim.defer_fn(function() vim.cmd("VimBeGood") end, 50)
end, { force = true })
