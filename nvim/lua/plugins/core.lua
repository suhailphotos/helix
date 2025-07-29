-- nvim/lua/plugins/core.lua
return {
  -- Astro core (must load first)
  {
    "AstroNvim/astrocore",
    version = "^2",  -- stay on the current major line
    lazy    = false, -- load immediately
  },
  {
    "AstroNvim/astroui",
    version = "^2",
    lazy    = false,
  },
  {
    "AstroNvim/astrolsp",
    version = "^3",
    lazy    = false,
  },

  -- Meta-package that pulls in the rest of AstroNvim
  {
    "AstroNvim/AstroNvim",
    version = "^5",
    lazy    = false,
  },
}
