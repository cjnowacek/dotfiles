return {
  "gaoDean/autolist.nvim",
  ft = { "markdown", "text" },
  config = function()
    local autolist = require("autolist")
    autolist.setup()

    -- Insert mode: indent/dedent/continue list properly
    vim.keymap.set("i", "<Tab>", "<cmd>AutolistTab<cr>")
    vim.keymap.set("i", "<S-Tab>", "<cmd>AutolistShiftTab<cr>")
    vim.keymap.set("i", "<CR>", "<cmd>AutolistNewBullet<cr>")

    -- Normal mode: new bullets, recalc after shifts/deletes, toggle checkbox
    vim.keymap.set("n", "o", "<cmd>AutolistNewBullet<cr>")
    vim.keymap.set("n", "O", "<cmd>AutolistNewBulletBefore<cr>")
    vim.keymap.set("n", ">>", ">><cmd>AutolistRecalculate<cr>")
    vim.keymap.set("n", "<<", "<<<cmd>AutolistRecalculate<cr>")
    vim.keymap.set("n", "dd", "dd<cmd>AutolistRecalculate<cr>")
    vim.keymap.set("n", "x", "<cmd>AutolistToggleCheckbox<cr>") -- on [ ] lines
  end,
}
