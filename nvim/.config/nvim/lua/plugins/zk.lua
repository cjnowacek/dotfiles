-- lua/plugins/zk.lua
return {
  "mickael-menu/zk-nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  ft = { "markdown" },
  cmd = { "ZkNew", "ZkNotes", "ZkTags", "ZkBacklinks", "ZkLinks", "ZkIndex", "ZkMatch" },
  keys = function()
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { silent = true, noremap = true, desc = desc })
    end
    local zkcmd = function(name, opts)
      return function()
        require("zk.commands").get(name)(opts or {})
      end
    end

    map("n", "<leader>zn", function()
      local title = vim.fn.input("Title: ")
      require("zk").new({ title = title ~= "" and title or nil })
    end, "Zk: New note")

    map("n", "<leader>zf", zkcmd("ZkNotes"), "Zk: Find notes")
    map("n", "<leader>zt", zkcmd("ZkTags"), "Zk: Browse tags")
    map("n", "<leader>zb", zkcmd("ZkBacklinks"), "Zk: Backlinks")
    map("n", "<leader>zl", zkcmd("ZkLinks"), "Zk: Links from note")
    map("n", "<leader>zi", zkcmd("ZkIndex"), "Zk: Open index")

    map("n", "<leader>zF", function()
      require("zk.commands").get("ZkNotes")({ cwd = vim.fn.expand("%:p:h") })
    end, "Zk: Find notes (cwd)")

    map("n", "<leader>zg", function()
      local q = vim.fn.input("Search: ")
      if q ~= "" then
        require("zk.commands").get("ZkNotes")({ match = { any = { q } } })
      end
    end, "Zk: Full-text search")

    map("n", "<leader>zd", function()
      local today = os.date("%Y-%m-%d")
      require("zk").new({
        title = "Daily " .. today,
        dir = "daily",
        template = "daily.md",
      })
    end, "Zk: New daily")
  end,
  opts = {
    picker = "telescope",
    lsp = {
      -- IMPORTANT: lsp.config must be a TABLE, not a function
      config = (function()
        local capabilities = vim.lsp.protocol.make_client_capabilities()
        local ok, cmp = pcall(require, "cmp_nvim_lsp")
        if ok then
          capabilities = cmp.default_capabilities(capabilities)
        end
        return {
          cmd = { "zk", "lsp" },
          name = "zk",
          capabilities = capabilities,
          on_attach = function(_, bufnr)
            local function bmap(mode, lhs, rhs, desc)
              vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
            end
            bmap("n", "gd", vim.lsp.buf.definition, "LSP: Go to definition")
            bmap("n", "K", vim.lsp.buf.hover, "LSP: Hover")
            bmap("n", "<leader>cr", vim.lsp.buf.rename, "LSP: Rename")
            bmap("n", "<leader>ca", vim.lsp.buf.code_action, "LSP: Code action")
          end,
        }
      end)(),
      auto_attach = {
        enabled = true,
        filetypes = { "markdown" }, -- keep this if your notes are markdown
      },
    },
  },
  config = function(_, opts)
    require("zk").setup(opts)
  end,
}
