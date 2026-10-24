return {
  {
    "AlexanderInnerbichler/signal.nvim",
    lazy = false,
    dev = true,
    config = function()
      require("signal").setup()
    end,
  },
}
