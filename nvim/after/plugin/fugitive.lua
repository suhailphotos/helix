-- fugitive loads lazily when :Git is first invoked,
-- so a guard isn’t strictly needed, but harmless to add.
local ok = pcall(require, "vim-fugitive")
if ok then
  vim.keymap.set("n", "<leader>gs", vim.cmd.Git)
end
