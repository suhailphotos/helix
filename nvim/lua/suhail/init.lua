-- lua/suhail/init.lua
require("suhail.remap")
require("suhail.set")

-- load plugin definitions (this also loads packer itself)
-- Temporary shim until packer removes deprecated call
if vim.tbl_islist == nil and vim.islist then
  vim.tbl_islist = vim.islist
end
require("suhail.packer")
