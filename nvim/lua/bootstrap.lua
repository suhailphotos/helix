-- nvim/lua/bootstrap.lua  (run ONLY during first-time install)
local fn  = vim.fn
local path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if fn.empty(fn.glob(path)) > 0 then
  fn.system({"git","clone","--depth","1",
             "https://github.com/wbthomason/packer.nvim", path})
end

vim.cmd("packadd packer.nvim")

-- do *not* load your real plugins.lua – just register them quickly
require("suhail.packer")   -- ← the file that calls `return require('packer').startup(...)`

-- kick off a full sync and quit when done
require("packer").sync()
vim.cmd [[
  augroup PackerDone
    autocmd!
    autocmd User PackerComplete quitall
  augroup END
]]
