-- lua/suhail/providers.lua
-- Point Neovim at a stable Python host, and quiet providers you don't use.

local host = vim.fn.expand("~/.venvs/nvim/bin/python")
if vim.fn.executable(host) == 1 then
  vim.g.python3_host_prog = host
end

-- Unless you explicitly need them, disable other providers to silence health warnings.
vim.g.loaded_node_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
