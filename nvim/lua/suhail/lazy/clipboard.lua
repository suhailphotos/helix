-- lua/suhail/lazy/clipboard.lua
return {
  {
    "ojroques/nvim-osc52",
    event = "VeryLazy",
    config = function()
      local osc52 = require("osc52")
      osc52.setup({}) -- defaults are fine

      local uname = vim.loop.os_uname().sysname
      local is_darwin = uname == "Darwin"
      local is_linux  = uname == "Linux"
      local function has(cmd) return vim.fn.executable(cmd) == 1 end

      -- Do we have a native system clipboard provider available?
      local has_sysclip = (is_darwin and has("pbcopy") and has("pbpaste"))
        or (is_linux and (has("wl-copy") or has("xclip") or has("xsel")))

      -- Are we on a remote host?
      local is_ssh = (vim.env.SSH_CONNECTION ~= nil) or (vim.env.SSH_TTY ~= nil)

      if not is_ssh and has_sysclip then
        -- Local machine with system clipboard → use it
        -- (Neovim will use pbcopy/pbpaste on macOS, wl-copy/xclip/xsel on Linux)
        vim.opt.clipboard = "unnamedplus"
        return
      end

      -- Remote (SSH) OR no native provider → use OSC52 to copy to the local terminal’s clipboard
      vim.g.clipboard = {
        name = "osc52",
        copy = { ["+"] = osc52.copy, ["*"] = osc52.copy },
        -- We don’t try to paste *from* local into remote; keep it empty.
        paste = {
          ["+"] = function() return { "" }, { "" } end,
          ["*"] = function() return { "" }, { "" } end,
        },
      }

      -- Make normal yanks hit the + register so they go through the provider.
      -- If you prefer to keep default yanks internal, remove this line and use your <leader>y maps.
      vim.opt.clipboard = "unnamedplus"
    end,
  },
}
