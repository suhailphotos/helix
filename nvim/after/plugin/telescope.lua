-- guard ---------------------------------------------------------------
local ok, telescope = pcall(require, "telescope.builtin")
if not ok then return end
-----------------------------------------------------------------------

vim.keymap.set("n", "<leader>pf", telescope.find_files, {})
vim.keymap.set("n", "<C-p>",      telescope.git_files,  {})
vim.keymap.set("n", "<leader>ps", function()
  telescope.grep_string { search = vim.fn.input("Grep > ") }
end)
