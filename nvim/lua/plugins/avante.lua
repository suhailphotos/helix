-- nvim/lua/plugins/avante.lua
return {
  "yetone/avante.nvim",
  -- load *after* the dashboard so it doesn’t steal the UI
  event = "User AstroFile",          -- lazy-load after startup
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",   -- icons provider → removes the warning
  },
  opts = {},
}
