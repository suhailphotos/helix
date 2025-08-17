return {
  "alexghergh/nvim-tmux-navigation",
  config = function()
    require("nvim-tmux-navigation").setup {
      disable_when_zoomed = true,
    }
    local n = require("nvim-tmux-navigation")
    vim.keymap.set("n", "<C-h>", n.NvimTmuxNavigateLeft)
    vim.keymap.set("n", "<C-j>", n.NvimTmuxNavigateDown)
    vim.keymap.set("n", "<C-k>", n.NvimTmuxNavigateUp)
    vim.keymap.set("n", "<C-l>", n.NvimTmuxNavigateRight)
    vim.keymap.set("n", [[<C-\>]], n.NvimTmuxNavigateLastActive)  -- << this line changed
    vim.keymap.set("n", "<C-Space>", n.NvimTmuxNavigateNext)
  end,
}
