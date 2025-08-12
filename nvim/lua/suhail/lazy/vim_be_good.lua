-- lua/suhail/lazy/vim_be_good.lua
return {
  { "ThePrimeagen/vim-be-good", cmd = "VimBeGood" },
  {
    "m4xshen/hardtime.nvim",
    -- no `cmd = {"Hardtime"}` needed with the retry loader above
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      enabled = false,  -- start OFF; we enable via PracticeOn
      disabled_filetypes = { "neo-tree", "qf", "help", "lazy", "TelescopePrompt" },
    },
  },
}
