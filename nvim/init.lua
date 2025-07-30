-- set leaders *first*
vim.g.mapleader      = " "
vim.g.maplocalleader = ","

-- bootstrap lazy.nvim (unchanged ↓)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- load every spec in lua/plugins/**
require("lazy").setup("plugins")

-- *then* load your prefs
require("suhail.options")
require("suhail.keymaps")
require("suhail.autocmds")
