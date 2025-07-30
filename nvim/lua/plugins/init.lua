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
  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts  = {
      ensure_installed = { "vimdoc","lua","python",
                           "javascript","typescript","rust","c" },
      auto_install     = true,    
      highlight        = { enable = true },
    },
    config = function(_, opts)
      local install = require("nvim-treesitter.install")
      install.parser_install_dir =
        vim.fn.stdpath("data") .. "/parsers"   -- ~/.local/share/nvim/parsers
      vim.opt.rtp:append(install.parser_install_dir)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
  ----------------------------------------------------------------------
  -- Git goodies & misc
  "tpope/vim-fugitive",
  "theprimeagen/harpoon",
  "mbbill/undotree",

  ----------------------------------------------------------------------
  -- LSP + completion  (your old lsp.lua will still run)
  { "VonHeikemen/lsp-zero.nvim", branch = "v1.x",
    dependencies = {
      -- LSP
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      -- completion
      "hrsh7th/nvim-cmp", "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-path",
      "hrsh7th/cmp-buffer", "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-nvim-lua",
      -- snippets
      "L3MON4D3/LuaSnip", "rafamadriz/friendly-snippets",
    }
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
    opts = {},   -- your Avante config table
  },
}
