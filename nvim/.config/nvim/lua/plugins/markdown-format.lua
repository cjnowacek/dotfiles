return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters_by_ft = opts.formatters_by_ft or {}
    opts.formatters_by_ft.markdown = { "prettier" }
    opts.formatters_by_ft.mdx = { "prettier" }
    opts.format_on_save = function(buf)
      -- only format markdown-like files on save
      local ft = vim.bo[buf].filetype
      if ft == "markdown" or ft == "mdx" then
        return { timeout_ms = 3000, lsp_fallback = false }
      end
      return nil  -- explicitly return nil for other file types
    end
  end,
}
