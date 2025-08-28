-- ~/.config/nvim/lua/plugins/bullets.lua
return {
  "dkarter/bullets.vim",
  ft = { "markdown", "text" },
  init = function()
    vim.g.bullets_enabled_file_types = { "markdown", "text" }
  end,
}
