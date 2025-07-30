require('suhail')
-- ─── bootstrap packer ──────────────────────────────────────────────────────
local fn  = vim.fn
local path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"

if fn.empty(fn.glob(path)) > 0 then
  print("  Installing packer, please wait…")
  fn.system({"git", "clone", "--depth", "1",
             "https://github.com/wbthomason/packer.nvim", path})
  vim.cmd("packadd packer.nvim")
end
