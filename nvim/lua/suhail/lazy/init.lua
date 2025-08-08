return {
  -- Core libs
  { "nvim-lua/plenary.nvim", name = "plenary" },
  { "nvim-tree/nvim-web-devicons", opts = {} },
  { "gpanders/editorconfig.nvim" },

  -- Colors
  require("suhail.lazy.colors"),

  -- Telescope
  require("suhail.lazy.telescope"),

  -- Treesitter
  require("suhail.lazy.treesitter"),

  -- LSP & completion
  require("suhail.lazy.lsp"),

  -- Git & utils
  require("suhail.lazy.fugitive"),
  require("suhail.lazy.undotree"),
  require("suhail.lazy.trouble"),

  -- Harpoon v2
  require("suhail.lazy.harpoon"),

  -- Avante (AI code assistant)
  require("suhail.lazy.avante"),

  -- tmux navigation between splits/panes
  require("suhail.lazy.tmux_nav"),
}
