-- undotree is pure Vimscript; just wrap the keybind
vim.keymap.set("n", "<leader>u", function()
  pcall(vim.cmd.UndotreeToggle)
end)
