return {
  {
    "AlphaTechnolog/pywal.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      require("pywal").setup()
      vim.cmd("colorscheme pywal")
    end,
  },
  -- tell LazyVim to stop forcing its own default theme
  { "LazyVim/LazyVim", opts = { colorscheme = "pywal" } },
}
