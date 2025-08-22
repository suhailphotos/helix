vim.g.mapleader = " "
vim.keymap.set('n', "<leader>pv", vim.cmd.Ex)

-- move selected lines up/down
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- clipboard/yank helpers
vim.keymap.set({"n","v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({"n","v"}, "<leader>d", [["_d]])

vim.keymap.set("x", "<leader>p", [["_dP]])  -- paste without clobbering
vim.keymap.set("i", "<C-c>", "<Esc>")       -- controversial but handy

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end)

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set("n", "<leader>s",
  [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

-- safe source current file
vim.keymap.set("n", "<leader><leader>", function() vim.cmd("so") end)

-- Optional: tmux sessionizer (won't error if missing)
vim.keymap.set("n", "<C-f>", function()
  vim.fn.jobstart({"tmux", "neww", "tmux-sessionizer"}, { detach = true })
end, { silent = true })
