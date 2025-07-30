-- nvim/lua/plugins/core.lua
return {
  -- Astro core modules (keep these)
  { 
    "AstroNvim/astrocore", 
    lazy = false, 
    version = "^2",
    opts = {            -- <<---------------------- add this block
      colorscheme = "rose-pine",
    },
  },
  { "AstroNvim/astroui",   lazy = false, version = "^2" },
  { "AstroNvim/astrolsp",  lazy = false, version = "^3" },

  -- full AstroNvim plugin set  ↓↓↓  (this line is the important bit)
  { "AstroNvim/AstroNvim", lazy = false, version = "^5", import = "astronvim.plugins" },
}
