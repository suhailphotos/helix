-- ── bootstrap lazy.nvim ─────────────────────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then         -- first run: clone
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ── plugin spec (convert your old `packer.use` list) ────────────────
require("lazy").setup({
  -- 1-to-1 mappings from packer:
  { "rose-pine/neovim", name = "rose-pine", priority = 1000,
    config = function()
      require("rose-pine").setup { disable_background = true }
      vim.cmd.colorscheme("rose-pine")
      vim.api.nvim_set_hl(0, "Normal",      { bg = "none" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    end
  },

  { "nvim-lua/plenary.nvim" },
  { "nvim-telescope/telescope.nvim", version = "0.1.6", dependencies = "plenary.nvim",
    cmd = "Telescope" },                         -- lazy-load on :Telescope
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "nvim-treesitter/playground" },
  { "theprimeagen/harpoon" },
  { "mbbill/undotree",           cmd = "UndotreeToggle" },
  { "tpope/vim-fugitive",        cmd = "Git" },

  { "yetone/avante.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    event = "VeryLazy",
    opts  = {},                  -- ← your Avante settings
  },

  -- lsp-zero bundle  (exactly the same plugins, just listed inline)
  { "VonHeikemen/lsp-zero.nvim", branch = "v1.x",
    dependencies = {
      -- LSP Support
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",

      -- Autocompletion
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lua",

      -- Snippets
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
    },
  },
})
require("lazy_boot")
require('suhail')

