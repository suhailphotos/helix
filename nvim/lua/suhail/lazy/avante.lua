-- Avante: AI assistant (requires Neovim >= 0.10.1)
return {
  "yetone/avante.nvim",
  version = false,
  event = "VeryLazy",
  build = (vim.fn.has("win32") ~= 0) and
          "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
          or "make",
  opts = {
    -- Pick your default provider. Requires matching credentials in env.
    -- Common choices: "claude", "copilot", "openai", "ollama"
    provider = "claude",
    providers = {
      claude = {
        endpoint = "https://api.anthropic.com",
        model = "claude-sonnet-4-20250514",
        timeout = 30000,
        extra_request_body = { temperature = 0.4, max_tokens = 4096 },
      },
      -- Example local model via Ollama:
      -- ollama = { endpoint = "http://localhost:11434", model = "qwen2.5-coder:7b" },
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    -- markdown / images (recommended)
    { "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        latex = { enable = false },
        html = { enable = false },
      }
    },
    { "HakonHarnes/img-clip.nvim", opts = { default = { embed_image_as_base64 = false, prompt_for_file_name = false } } },
    -- optional quality-of-life
    "hrsh7th/nvim-cmp",
    "nvim-tree/nvim-web-devicons",
    -- enable this if you want provider = "copilot"
    -- "zbirenbaum/copilot.lua",
  },
}
