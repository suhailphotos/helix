-- 0.  YOUR LEADER KEYS  ────────────────────────────────────────────────────
vim.g.mapleader      = " "     -- <Space> is the main leader
vim.g.maplocalleader = ","     -- (optional) local leader

-- 1. Decide where lazy.nvim should live
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
--   stdpath("data") → ~/.local/share/nvim   (on macOS/Linux)

-- 2. If it’s not there, clone it
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({          -- run an external command
    "git", "clone",
    "--filter=blob:none",  -- don't download every file history
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath
  })
end

-- 3. Put lazy.nvim on Neovim’s runtimepath
vim.opt.rtp:prepend(lazypath)

-- 4. Tell lazy.nvim to read all plugin specs under lua/plugins/**
require("lazy").setup("plugins")

-- 5. Load your own options, keymaps, autocmds
require("suhail.options")
require("suhail.keymaps")
require("suhail.autocmds")
