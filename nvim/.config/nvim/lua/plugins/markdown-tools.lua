-- ~/.config/nvim/lua/plugins/treesitter-md.lua
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    ensure_installed = { "markdown", "markdown_inline" },
    highlight = { enable = true },
  },
}
