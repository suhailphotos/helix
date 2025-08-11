return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/nvim-cmp",
    "L3MON4D3/LuaSnip",
    "saadparwaiz1/cmp_luasnip",
    "j-hui/fidget.nvim",
  },
  config = function()
    local cmp = require("cmp")
    local cmp_lsp = require("cmp_nvim_lsp")
    local capabilities = vim.tbl_deep_extend(
      "force",
      {},
      vim.lsp.protocol.make_client_capabilities(),
      cmp_lsp.default_capabilities()
    )

    require("fidget").setup({})
    require("mason").setup()
    require("mason-lspconfig").setup({
      automatic_enable = false,
      ensure_installed = { "lua_ls", "pylsp", "ts_ls" },  -- ← no rust_analyzer here
      handlers = {
        function(server) require("lspconfig")[server].setup({ capabilities = capabilities }) end,
        ["lua_ls"] = function()
          require("lspconfig").lua_ls.setup({
            capabilities = capabilities,
            settings = { Lua = { diagnostics = { globals = { "vim" } } } },
          })
        end,
        ["pylsp"] = function()
          require("lspconfig").pylsp.setup({
            capabilities = capabilities,
            settings = {
              pylsp = {
                plugins = {
                  ruff = { enabled = true, extendSelect = { "I" }, lineLength = 88 },
                  flake8 = { enabled = false },
                  mccabe = { enabled = false },
                  pycodestyle = { enabled = false },
                  pyflakes = { enabled = false },
                  yapf = { enabled = false },
                },
              },
            },
          })
        end,
      },
    })

    -- Use Homebrew's rust-analyzer found on PATH
    require("lspconfig").rust_analyzer.setup({ capabilities = capabilities })

    local cmp_select = { behavior = cmp.SelectBehavior.Select }
    cmp.setup({
      snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
      mapping = cmp.mapping.preset.insert({
        ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
        ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
        ["<C-y>"] = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
      }),
      sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "luasnip" } }, { { name = "buffer" } }),
    })

    vim.diagnostic.config({
      float = { focusable = false, style = "minimal", border = "rounded", source = "always", header = "", prefix = "" },
    })
  end,
}
