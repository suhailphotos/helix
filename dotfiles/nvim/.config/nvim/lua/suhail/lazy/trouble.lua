return {
  "folke/trouble.nvim",
  opts = { icons = false },
  keys = {
    { "<leader>tt", function() require("trouble").toggle() end, desc = "Toggle Trouble" },
    { "[t", function() require("trouble").next({skip_groups = true, jump = true}) end, desc = "Next Trouble" },
    { "]t", function() require("trouble").previous({skip_groups = true, jump = true}) end, desc = "Prev Trouble" },
  },
}
