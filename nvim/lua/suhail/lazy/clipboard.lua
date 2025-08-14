-- lua/suhail/lazy/clipboard.lua
return {
  {
    "ojroques/nvim-osc52",
    event = "VeryLazy",
    config = function()
      local osc52 = require("osc52")
      osc52.setup({
        -- helpful defaults; tune if you like
        max_length = 0,  -- no limit (some terminals truncate long OSC52)
        silent = true,
        trim = false,
      })

      local uname = vim.loop.os_uname().sysname
      local is_darwin = uname == "Darwin"
      local is_linux  = uname == "Linux"
      local function has(cmd) return vim.fn.executable(cmd) == 1 end

      -- Native clipboard available locally?
      local has_sysclip = (is_darwin and has("pbcopy") and has("pbpaste"))
        or (is_linux and (has("wl-copy") or has("xclip") or has("xsel")))

      -- On a remote shell?
      local is_ssh = (vim.env.SSH_CONNECTION ~= nil) or (vim.env.SSH_TTY ~= nil)

      if not is_ssh and has_sysclip then
        -- Local machine with a system clipboard → let Neovim use it
        vim.opt.clipboard = "unnamedplus"
        return
      end

      -- Remote (SSH) or no native provider → OSC52 provider
      local function copy_lines(lines, _)
        osc52.copy(table.concat(lines, "\n"))
      end
      local function paste_stub()
        -- We generally don't paste from the local clipboard back to remote
        return { "" }, { "" }
      end

      vim.g.clipboard = {
        name = "osc52",
        copy = { ["+"] = copy_lines, ["*"] = copy_lines },
        paste = { ["+"] = paste_stub, ["*"] = paste_stub },
      }

      -- Send default yanks to + so they run through the provider
      vim.opt.clipboard = "unnamedplus"

      -- Optional: mappings to force OSC52 copy on demand
      -- vim.keymap.set("n", "<leader>cy", function() osc52.copy(vim.fn.getreg("%")) end)
      -- vim.keymap.set("v", "<leader>y", osc52.copy_visual)
    end,
  },
}
