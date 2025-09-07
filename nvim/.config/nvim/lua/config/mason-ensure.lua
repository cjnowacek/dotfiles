return {
  "williamboman/mason.nvim",
  opts = {
    ensure_installed = {
      -- LSP Servers
      "lua-language-server",
      "pyright",
      "marksman",
      "bashls",
      "terraformls",
      -- Formatters
      "prettier",
      "stylua",
      "black",
      -- Linters
      "eslint_d",
      "flake8",
    },
  },
}
