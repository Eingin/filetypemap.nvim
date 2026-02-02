---@class FiletypemapConfig
---@field notify boolean Show notification when mappings are loaded

---@class FiletypemapModule
---@field config FiletypemapConfig
---@field current_mappings table<string, string>
local M = {}

local FILENAME = ".filetypemap"

---@type FiletypemapConfig
local defaults = {
	notify = true,
}

M.config = vim.deepcopy(defaults)
M.current_mappings = {}

--- Get the extension from a filename
---@param filename string
---@return string|nil
local function get_extension(filename)
	return filename:match("%.([^%.]+)$")
end

--- Parse a .filetypemap file and return extension mappings
---@param filepath string
---@return table<string, string>
function M.parse(filepath)
	local mappings = {}
	local file = io.open(filepath, "r")
	if not file then
		return mappings
	end

	for line in file:lines() do
		line = vim.trim(line)
		-- Skip empty lines and comments
		if line ~= "" and not vim.startswith(line, "#") then
			local ext, filetype = line:match("^([^=]+)=(.+)$")
			if ext and filetype then
				mappings[vim.trim(ext)] = vim.trim(filetype)
			end
		end
	end

	file:close()
	return mappings
end

--- Detect and set filetype for a buffer using current mappings
--- Only sets filetype if extension is in our mappings
---@param bufnr number
---@return boolean whether we set a filetype
function M.detect_filetype(bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	if filename == "" then
		return false
	end

	local ext = get_extension(filename)
	if not ext then
		return false
	end

	local mapped_ft = M.current_mappings[ext]
	if mapped_ft then
		vim.bo[bufnr].filetype = mapped_ft
		return true
	end

	return false
end

--- Re-detect filetypes for all buffers affected by mapping changes
---@param old_mappings table<string, string>
---@param new_mappings table<string, string>
local function refresh_affected_buffers(old_mappings, new_mappings)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local filename = vim.api.nvim_buf_get_name(bufnr)
			local ext = get_extension(filename)
			if ext then
				local was_mapped = old_mappings[ext]
				local is_mapped = new_mappings[ext]

				if is_mapped then
					-- Apply new mapping
					vim.bo[bufnr].filetype = is_mapped
				elseif was_mapped then
					-- Was mapped, now isn't - reset to Neovim's detection
					local detected = vim.filetype.match({ filename = filename, buf = bufnr })
					vim.bo[bufnr].filetype = detected or ""
				end
			end
		end
	end
end

--- Load .filetypemap from cwd and apply mappings
---@return number count Number of mappings loaded
function M.load()
	local cwd = vim.fn.getcwd()
	local filepath = cwd .. "/" .. FILENAME

	local old_mappings = M.current_mappings

	if vim.fn.filereadable(filepath) == 1 then
		M.current_mappings = M.parse(filepath)
	else
		M.current_mappings = {}
	end

	local count = vim.tbl_count(M.current_mappings)

	-- Refresh buffers affected by the mapping change
	refresh_affected_buffers(old_mappings, M.current_mappings)

	if count > 0 and M.config.notify then
		vim.notify(
			string.format("Loaded %d filetype mapping%s from %s", count, count == 1 and "" or "s", FILENAME),
			vim.log.levels.INFO
		)
	end

	return count
end

--- Setup the plugin with user configuration
---@param opts? FiletypemapConfig
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", defaults, opts or {})

	local augroup = vim.api.nvim_create_augroup("filetypemap", { clear = true })

	-- Detect filetype for new buffers using our mappings
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = augroup,
		callback = function(args)
			M.detect_filetype(args.buf)
		end,
	})

	-- Reload when cwd changes
	vim.api.nvim_create_autocmd("DirChanged", {
		group = augroup,
		callback = function()
			M.load()
		end,
	})

	-- Load mappings on setup
	M.load()

	-- Create user command
	vim.api.nvim_create_user_command("FiletypeMapReload", function()
		M.load()
	end, { desc = "Reload .filetypemap from current directory" })
end

return M
