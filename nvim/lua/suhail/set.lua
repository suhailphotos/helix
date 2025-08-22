-- Basics
vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = (os.getenv("HOME") or "~") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
-- vim.opt.colorcolumn = "80"

-- Misc niceties
local augroup = vim.api.nvim_create_augroup
local SuhailGroup = augroup('Suhail', {})
vim.api.nvim_create_autocmd('TextYankPost', {
  group = SuhailGroup,
  callback = function()
    vim.highlight.on_yank({higroup='IncSearch', timeout=120})
  end,
})
-- trim trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
  group = SuhailGroup,
  pattern = "*",
  command = [[%s/\s\+$//e]],
})
