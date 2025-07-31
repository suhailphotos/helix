-- nvim/init.lua ----------------------------------------------------
vim.g.mapleader = " "            -- ❶ set *before* lazy loads
vim.g.maplocalleader = " "       -- (good practice for plugins)



-- new: work from nvim’s cache dir, never from project folders
-- vim.fn.chdir(vim.fn.stdpath("data"))   -- ~/.local/share/nvim

require("lazy_boot")   -- or whatever follows in your file …

-- bootstrap lazy.nvim ---------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- single plugin spec ----------------------------------------------
require("lazy").setup({
  { import = "plugins" },       -- reads lua/plugins/init.lua
})

-- your options / key-maps -----------------------------------------
require("suhail")
--------------------------------------------------------------------
