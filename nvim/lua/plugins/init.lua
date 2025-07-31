-- nvim/lua/plugins/init.lua  ------------------------------------------
return {
  ----------------------------------------------------------------------
  -- UI / theme
  { "rose-pine/neovim", name = "rose-pine", priority = 1000,
    config = function()
      require("rose-pine").setup { disable_background = true }
      vim.cmd.colorscheme("rose-pine")
      vim.api.nvim_set_hl(0,"Normal",{bg="none"})
      vim.api.nvim_set_hl(0,"NormalFloat",{bg="none"})
    end
  },

  ----------------------------------------------------------------------
  -- Telescope
  { "nvim-telescope/telescope.nvim", tag = "0.1.6",
    dependencies = { "nvim-lua/plenary.nvim" } },

  ----------------------------------------------------------------------
  -- **Explorer like AstroNvim**
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",   -- already in your tree
      "MunifTanjim/nui.nvim",          -- already in your tree
    },
    keys = {
      { "<leader>e", ":Neotree toggle<CR>", desc = "Explorer (neo-tree)" },
    },
    opts = {
      window = { position = "left", width = 30 },
      filesystem = {
        filtered_items = { visible = true, show_hidden_count = true },
      },
      default_component_configs = {
        indent = { padding = 0 },
        icon   = { folder_closed = "", folder_open = "" },
      },
    },
  },

  ----------------------------------------------------------------------
  -- Git goodies & misc
  "tpope/vim-fugitive",
  "theprimeagen/harpoon",
  "mbbill/undotree",

  ----------------------------------------------------------------------
  -- LSP + completion
  { "VonHeikemen/lsp-zero.nvim", branch = "v1.x",
    dependencies = {
      "neovim/nvim-lspconfig", "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp", "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path", "hrsh7th/cmp-buffer",
      "saadparwaiz1/cmp_luasnip", "hrsh7th/cmp-nvim-lua",
      "L3MON4D3/LuaSnip", "rafamadriz/friendly-snippets",
    },
  },

  ----------------------------------------------------------------------
  -- Avante (AI helper)
  { "yetone/avante.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },
}
