-- Minimal init.lua for running tests
vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=]])

-- Add this plugin to runtimepath
local plugin_path = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
vim.opt.runtimepath:append(plugin_path)

-- Add mini.nvim for testing
local mini_path = plugin_path .. "deps/mini.nvim"
vim.opt.runtimepath:append(mini_path)

-- Set up mini.test
require("mini.test").setup()
