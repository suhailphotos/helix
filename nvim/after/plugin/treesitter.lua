-- guard ---------------------------------------------------------------
local ok, ts = pcall(require, "nvim-treesitter.configs")
if not ok then return end
-----------------------------------------------------------------------

ts.setup {
  ensure_installed = { "vimdoc", "javascript", "typescript", "python", "c", "lua", "rust" },
  auto_install     = true,
  highlight        = { enable = true, additional_vim_regex_highlighting = false },
}
