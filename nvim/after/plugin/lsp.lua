-- guard ---------------------------------------------------------------
local ok, lsp = pcall(require, "lsp-zero")
if not ok then return end
-----------------------------------------------------------------------

lsp.preset("recommended")

lsp.ensure_installed({
  "rust_analyzer",
  "pylsp",
})

lsp.nvim_workspace()

-- … (everything that follows is identical to your current file)
local cmp         = require("cmp")
local cmp_select  = { behavior = cmp.SelectBehavior.Select }
local cmp_mapping = lsp.defaults.cmp_mappings({
  ["<C-p>"]     = cmp.mapping.select_prev_item(cmp_select),
  ["<C-n>"]     = cmp.mapping.select_next_item(cmp_select),
  ["<C-y>"]     = cmp.mapping.confirm({ select = true }),
  ["<C-Space>"] = cmp.mapping.complete(),
})
cmp_mapping["<Tab>"]   = nil
cmp_mapping["<S-Tab>"] = nil
lsp.setup_nvim_cmp { mapping = cmp_mapping }

lsp.set_preferences({
  suggest_lsp_servers = false,
  sign_icons = { error = "E", warn = "W", hint = "H", info = "I" },
})

lsp.on_attach(function(_, bufnr)
  local map = function(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, remap = false })
  end
  map("n", "gd",         vim.lsp.buf.definition)
  map("n", "K",          vim.lsp.buf.hover)
  map("n", "<leader>vws",vim.lsp.buf.workspace_symbol)
  map("n", "<leader>vd", vim.diagnostic.open_float)
  map("n", "[d",         vim.diagnostic.goto_next)
  map("n", "]d",         vim.diagnostic.goto_prev)
  map("n", "<leader>vca",vim.lsp.buf.code_action)
  map("n", "<leader>vrr",vim.lsp.buf.references)
  map("n", "<leader>vrn",vim.lsp.buf.rename)
  map("i", "<C-h>",      vim.lsp.buf.signature_help)
end)

lsp.setup()

vim.diagnostic.config { virtual_text = true }

-- your custom pylsp settings stay unchanged --------------------------
require("lspconfig").pylsp.setup {
  settings = {
    pylsp = {
      plugins = {
        ruff        = { enabled = true, extendSelect = { "I" }, lineLength = 88 },
        flake8      = { enabled = false },
        mccabe      = { enabled = false },
        pycodestyle = { enabled = false },
        pyflakes    = { enabled = false },
        yapf        = { enabled = false },
      },
    },
  },
}
