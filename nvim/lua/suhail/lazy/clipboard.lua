-- lua/suhail/lazy/clipboard.lua
return {
  {
    "ojroques/nvim-osc52",
    event = "VeryLazy",
    config = function()
      local osc52 = require("osc52")

      -- Quiet, robust defaults
      osc52.setup({
        max_length = 0,   -- 0 = no limit (some terminals truncate otherwise)
        silent = true,
        trim = false,
      })

      -- Environment detection
      local sys = vim.loop.os_uname().sysname
      local is_darwin = (sys == "Darwin")
      local is_linux  = (sys == "Linux")
      local function has(cmd) return vim.fn.executable(cmd) == 1 end

      -- Do we have a native system clipboard tool locally?
      local has_sysclip = (is_darwin and has("pbcopy") and has("pbpaste"))
        or (is_linux and (has("wl-copy") or has("xclip") or has("xsel")))

      -- Are we on a remote shell?
      local is_ssh = (vim.env.SSH_CONNECTION ~= nil) or (vim.env.SSH_TTY ~= nil)

      -- We only need to back +/* with OSC52 if we're remote OR there is no native tool.
      local need_osc52 = is_ssh or not has_sysclip

      if need_osc52 then
        -- Neovim gives us a TABLE of lines; OSC52 wants a STRING.
        local function copy_lines(lines, _)
          osc52.copy(table.concat(lines, "\n"))
        end

        -- We generally don't pull from local OS clipboard back into remote.
        -- Return an empty paste; second value is the register type ("v" = characterwise).
        local function paste_stub()
          return { "" }, "v"
        end

        vim.g.clipboard = {
          name = "osc52",
          copy  = { ["+"] = copy_lines, ["*"] = copy_lines },
          paste = { ["+"] = paste_stub,  ["*"] = paste_stub  },
        }
      else
        -- Local with pbcopy/xclip/etc.
        -- Do NOT set `unnamedplus` — keep default Vim semantics.
        -- Explicit `"+y` / `"+p` will use system clipboard via Neovim's builtin provider.
      end

      -- IMPORTANT: Do NOT set `vim.opt.clipboard = "unnamedplus"`.
      -- This prevents deletes/yanks from clobbering your GUI clipboard.
      --
      -- If you ever want an explicit “copy via OSC52 now” mapping, you can add:
      -- vim.keymap.set("v", "<leader>y", osc52.copy_visual, { desc = "OSC52 copy" })
    end,
  },
}
