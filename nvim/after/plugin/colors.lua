-- guard ---------------------------------------------------------------
local ok, rose = pcall(require, "rose-pine")
if not ok then return end
-----------------------------------------------------------------------

rose.setup { disable_background = true }
vim.cmd.colorscheme("rose-pine")

-- transparent background
vim.api.nvim_set_hl(0, "Normal",      { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
