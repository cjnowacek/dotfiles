vim.opt_local.wrap = true
vim.opt_local.linebreak = true          -- wrap on word boundaries
vim.opt_local.breakindent = true        -- keep indent on wrapped lines
vim.opt_local.breakindentopt = "shift:2"
vim.opt_local.showbreak = "↪ "          -- prefix on wrapped screen lines
vim.opt_local.conceallevel = 2          -- hide **, ``, etc. (set 0 to see raw md)
vim.opt_local.spell = true              -- spell checking for prose
vim.opt_local.formatoptions:append("n") -- auto-continue numbered lists
vim.opt_local.formatoptions:remove({ "t" }) -- don't hard-wrap text automatically
