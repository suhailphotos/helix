-- lua/suhail/lazy/colors.lua
local function ColorMyPencils(color)
  if vim.env.NVIM_TRANSPARENT == "1" then
    color = color or "rose-pine"
    vim.cmd.colorscheme(color)
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
  end
end

return {
  -- Optional alternatives, available on demand with :colorscheme X
  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
    lazy = true,
    opts = {
      style = "storm",
      transparent = true,
      terminal_colors = true,
      styles = { comments = { italic = false }, keywords = { italic = false }, sidebars = "dark", floats = "dark" },
    },
  },

  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,                     -- make it on-demand now
    opts = { disable_background = true },
  },

  -- 🔹 Your default theme at startup
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,                    -- start plugin (loads at startup)
    priority = 1000,                 -- load before other start plugins
    opts = {
      flavour = "mocha",             -- or "auto" to follow :set background
      transparent_background = true, -- you can drop your manual bg = "none"
      term_colors = true,
      integrations = {
        treesitter = true,
        cmp = true,
        telescope = true,
        gitsigns = true,
        lsp_trouble = true,
      },
      custom_highlights = function(C)
        return {
          StatusLine   = { fg = C.overlay2, bg = "NONE" },  -- softer gray, no bg
          StatusLineNC = { fg = C.surface2, bg = "NONE" },
          WinSeparator = { fg = C.surface1, bg = "NONE" },  -- optional: subtle split line
          ModeMsg      = { fg = C.overlay2 },               -- optional: "-- INSERT --" color
        }
      end,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)   -- lazy.nvim will call this automatically when you use `opts`, but explicit is fine
      vim.cmd.colorscheme("catppuccin")   -- or "catppuccin-mocha", "catppuccin-macchiato", etc.
    end,
  },
}
