vim.pack.add({
  { src = "https://github.com/nvim-tree/nvim-tree.lua", version = vim.version.range("*") },
  "https://github.com/nvim-tree/nvim-web-devicons",
})

require("nvim-tree").setup({
  sort = {
    sorter = "case_sensitive",
  },
  view = {
    width = 30,
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = true,
  },
})
