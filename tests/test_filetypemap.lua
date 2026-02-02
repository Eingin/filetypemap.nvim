local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "scripts/minimal_init.lua" })
			-- Add plugin to runtimepath in child
			child.lua([[vim.opt.runtimepath:append(vim.fn.getcwd())]])
		end,
		post_once = child.stop,
	},
})

-- Helper to create a temp directory with optional .filetypemap
local function create_temp_dir(filetypemap_content)
	local dir = child.lua_get([[vim.fn.tempname()]])
	child.lua("vim.fn.mkdir(...)", { dir, "p" })
	if filetypemap_content then
		local filepath = dir .. "/.filetypemap"
		child.lua(
			[[
			local filepath, content = ...
			local f = io.open(filepath, 'w')
			f:write(content)
			f:close()
		]],
			{ filepath, filetypemap_content }
		)
	end
	return dir
end

-- Helper to clean up temp directory
local function remove_temp_dir(dir)
	child.lua("vim.fn.delete(..., 'rf')", { dir })
end

--------------------------------------------------------------------------------
-- M.parse() tests
--------------------------------------------------------------------------------
T["parse()"] = new_set()

T["parse()"]["returns empty table for non-existent file"] = function()
	child.lua([[M = require('filetypemap')]])
	local result = child.lua_get([[M.parse('/nonexistent/path/.filetypemap')]])
	eq(result, {})
end

T["parse()"]["parses simple mappings"] = function()
	local dir = create_temp_dir("container=systemd\nnetwork=systemd")
	child.lua([[M = require('filetypemap')]])
	local result = child.lua_get("M.parse(...)", { dir .. "/.filetypemap" })
	eq(result, { container = "systemd", network = "systemd" })
	remove_temp_dir(dir)
end

T["parse()"]["ignores comments"] = function()
	local dir = create_temp_dir("# This is a comment\nfoo=bar\n# Another comment")
	child.lua([[M = require('filetypemap')]])
	local result = child.lua_get("M.parse(...)", { dir .. "/.filetypemap" })
	eq(result, { foo = "bar" })
	remove_temp_dir(dir)
end

T["parse()"]["ignores empty lines"] = function()
	local dir = create_temp_dir("foo=bar\n\n\nbaz=qux")
	child.lua([[M = require('filetypemap')]])
	local result = child.lua_get("M.parse(...)", { dir .. "/.filetypemap" })
	eq(result, { foo = "bar", baz = "qux" })
	remove_temp_dir(dir)
end

T["parse()"]["trims whitespace"] = function()
	local dir = create_temp_dir("  foo  =  bar  \n  baz=qux")
	child.lua([[M = require('filetypemap')]])
	local result = child.lua_get("M.parse(...)", { dir .. "/.filetypemap" })
	eq(result, { foo = "bar", baz = "qux" })
	remove_temp_dir(dir)
end

T["parse()"]["ignores malformed lines"] = function()
	local dir = create_temp_dir("valid=mapping\nno_equals_sign\n=no_extension\nalso_valid=type")
	child.lua([[M = require('filetypemap')]])
	local result = child.lua_get("M.parse(...)", { dir .. "/.filetypemap" })
	eq(result, { valid = "mapping", also_valid = "type" })
	remove_temp_dir(dir)
end

--------------------------------------------------------------------------------
-- M.detect_filetype() tests
--------------------------------------------------------------------------------
T["detect_filetype()"] = new_set()

T["detect_filetype()"]["returns false for buffer with no name"] = function()
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.current_mappings = { foo = 'bar' }]])
	local bufnr = child.lua_get([[vim.api.nvim_create_buf(false, true)]])
	local result = child.lua_get("M.detect_filetype(...)", { bufnr })
	eq(result, false)
end

T["detect_filetype()"]["returns false for file with no extension"] = function()
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.current_mappings = { foo = 'bar' }]])
	local bufnr = child.lua_get([[vim.api.nvim_create_buf(false, true)]])
	child.lua("vim.api.nvim_buf_set_name(..., '/tmp/noextension')", { bufnr })
	local result = child.lua_get("M.detect_filetype(...)", { bufnr })
	eq(result, false)
end

T["detect_filetype()"]["returns false for unmapped extension"] = function()
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.current_mappings = { foo = 'bar' }]])
	local bufnr = child.lua_get([[vim.api.nvim_create_buf(false, true)]])
	child.lua("vim.api.nvim_buf_set_name(..., '/tmp/file.baz')", { bufnr })
	local result = child.lua_get("M.detect_filetype(...)", { bufnr })
	eq(result, false)
end

T["detect_filetype()"]["sets filetype for mapped extension"] = function()
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.current_mappings = { container = 'systemd' }]])
	local bufnr = child.lua_get([[vim.api.nvim_create_buf(false, true)]])
	child.lua("vim.api.nvim_buf_set_name(..., '/tmp/test.container')", { bufnr })
	local result = child.lua_get("M.detect_filetype(...)", { bufnr })
	eq(result, true)
	local ft = child.lua_get("vim.bo[...].filetype", { bufnr })
	eq(ft, "systemd")
end

--------------------------------------------------------------------------------
-- M.load() tests
--------------------------------------------------------------------------------
T["load()"] = new_set()

T["load()"]["returns 0 when no .filetypemap exists"] = function()
	local dir = create_temp_dir(nil)
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.config.notify = false]])
	local count = child.lua_get([[M.load()]])
	eq(count, 0)
	remove_temp_dir(dir)
end

T["load()"]["loads mappings from .filetypemap"] = function()
	local dir = create_temp_dir("foo=bar\nbaz=qux")
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.config.notify = false]])
	local count = child.lua_get([[M.load()]])
	eq(count, 2)
	local mappings = child.lua_get([[M.current_mappings]])
	eq(mappings, { foo = "bar", baz = "qux" })
	remove_temp_dir(dir)
end

T["load()"]["clears mappings when switching to dir without .filetypemap"] = function()
	local dir1 = create_temp_dir("foo=bar")
	local dir2 = create_temp_dir(nil)
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.config.notify = false]])

	-- Load from dir1
	child.lua("vim.fn.chdir(...)", { dir1 })
	child.lua_get([[M.load()]])
	eq(child.lua_get([[M.current_mappings]]), { foo = "bar" })

	-- Switch to dir2 (no .filetypemap)
	child.lua("vim.fn.chdir(...)", { dir2 })
	child.lua_get([[M.load()]])
	eq(child.lua_get([[M.current_mappings]]), {})

	remove_temp_dir(dir1)
	remove_temp_dir(dir2)
end

T["load()"]["refreshes buffer filetypes when mappings change"] = function()
	local dir1 = create_temp_dir("container=systemd")
	local dir2 = create_temp_dir("container=json")
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.config.notify = false]])

	-- Create a buffer with .container extension
	local bufnr = child.lua_get([[vim.api.nvim_create_buf(false, true)]])
	child.lua("vim.api.nvim_buf_set_name(..., '/tmp/test.container')", { bufnr })

	-- Load from dir1
	child.lua("vim.fn.chdir(...)", { dir1 })
	child.lua_get([[M.load()]])
	eq(child.lua_get("vim.bo[...].filetype", { bufnr }), "systemd")

	-- Switch to dir2 (different mapping)
	child.lua("vim.fn.chdir(...)", { dir2 })
	child.lua_get([[M.load()]])
	eq(child.lua_get("vim.bo[...].filetype", { bufnr }), "json")

	remove_temp_dir(dir1)
	remove_temp_dir(dir2)
end

T["load()"]["resets filetype when mapping is removed"] = function()
	local dir1 = create_temp_dir("lua=custom")
	local dir2 = create_temp_dir(nil)
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.config.notify = false]])

	-- Create a buffer with .lua extension
	local bufnr = child.lua_get([[vim.api.nvim_create_buf(false, true)]])
	child.lua("vim.api.nvim_buf_set_name(..., '/tmp/test.lua')", { bufnr })

	-- Load from dir1 (maps lua to custom)
	child.lua("vim.fn.chdir(...)", { dir1 })
	child.lua_get([[M.load()]])
	eq(child.lua_get("vim.bo[...].filetype", { bufnr }), "custom")

	-- Switch to dir2 (no mapping - should reset to default)
	child.lua("vim.fn.chdir(...)", { dir2 })
	child.lua_get([[M.load()]])
	-- Should be reset to Neovim's detection (lua for .lua files)
	eq(child.lua_get("vim.bo[...].filetype", { bufnr }), "lua")

	remove_temp_dir(dir1)
	remove_temp_dir(dir2)
end

--------------------------------------------------------------------------------
-- M.setup() tests
--------------------------------------------------------------------------------
T["setup()"] = new_set()

T["setup()"]["creates user command"] = function()
	local dir = create_temp_dir(nil)
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup({ notify = false })]])

	local commands = child.lua_get([[vim.api.nvim_get_commands({})]])
	expect.no_error(function()
		assert(commands["FiletypeMapReload"] ~= nil)
	end)
	remove_temp_dir(dir)
end

T["setup()"]["creates autocmds"] = function()
	local dir = create_temp_dir(nil)
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup({ notify = false })]])

	-- Count autocmds in the filetypemap group (can't serialize callback functions)
	local count = child.lua_get([[#vim.api.nvim_get_autocmds({ group = 'filetypemap' })]])
	-- Should have BufReadPost, BufNewFile, and DirChanged autocmds
	eq(count >= 2, true)
	remove_temp_dir(dir)
end

T["setup()"]["loads mappings on setup"] = function()
	local dir = create_temp_dir("foo=bar")
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup({ notify = false })]])

	local mappings = child.lua_get([[M.current_mappings]])
	eq(mappings, { foo = "bar" })
	remove_temp_dir(dir)
end

T["setup()"]["respects notify config option"] = function()
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup({ notify = false })]])
	eq(child.lua_get([[M.config.notify]]), false)

	child.lua([[M.setup({ notify = true })]])
	eq(child.lua_get([[M.config.notify]]), true)
end

T["setup()"]["uses default config when no opts provided"] = function()
	local dir = create_temp_dir(nil)
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup()]])
	eq(child.lua_get([[M.config.notify]]), true)
	remove_temp_dir(dir)
end

--------------------------------------------------------------------------------
-- DirChanged autocmd tests
--------------------------------------------------------------------------------
T["DirChanged"] = new_set()

T["DirChanged"]["reloads mappings when cwd changes"] = function()
	local dir1 = create_temp_dir("ext1=type1")
	local dir2 = create_temp_dir("ext2=type2")
	child.lua("vim.fn.chdir(...)", { dir1 })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup({ notify = false })]])

	eq(child.lua_get([[M.current_mappings]]), { ext1 = "type1" })

	-- Change directory (triggers DirChanged)
	child.lua("vim.fn.chdir(...)", { dir2 })
	-- Need to trigger the autocmd manually in headless mode
	child.lua([[vim.api.nvim_exec_autocmds('DirChanged', { group = 'filetypemap' })]])

	eq(child.lua_get([[M.current_mappings]]), { ext2 = "type2" })

	remove_temp_dir(dir1)
	remove_temp_dir(dir2)
end

--------------------------------------------------------------------------------
-- BufReadPost/BufNewFile autocmd tests
--------------------------------------------------------------------------------
T["BufReadPost"] = new_set()

T["BufReadPost"]["sets filetype for new buffers with mapped extension"] = function()
	local dir = create_temp_dir("container=systemd")
	child.lua("vim.fn.chdir(...)", { dir })
	child.lua([[M = require('filetypemap')]])
	child.lua([[M.setup({ notify = false })]])

	-- Create a temp file to edit
	local filepath = dir .. "/test.container"
	child.lua(
		[[
		local f = io.open(..., 'w')
		f:write('test content')
		f:close()
	]],
		{ filepath }
	)

	-- Open the file (triggers BufReadPost)
	child.lua("vim.cmd.edit(...)", { filepath })
	local ft = child.lua_get([[vim.bo.filetype]])
	eq(ft, "systemd")

	remove_temp_dir(dir)
end

return T
