-- lua/plugins/treesitter.lua
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  init = function()
    local install = require("nvim-treesitter.install")
--    install.parser_install_dir = vim.fn.stdpath("data") .. "/parsers"
    install.prefer_git         = false
--    install.temp_dir           = vim.fn.stdpath("data") .. "/ts_tmp"
    install.compilers          = { "clang", "gcc" }
    if install.parser_install_dir then
      vim.opt.rtp:append(install.parser_install_dir)
    end
    -- For debugging:
    print("TS parser dir: " .. install.parser_install_dir)
    print("TS temp dir: " .. install.temp_dir)
  end,
  opts = {
    ensure_installed = { "vimdoc", "lua", "python", "javascript", "typescript", "c", "rust" },
    auto_install = true,
    highlight = { enable = true },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
