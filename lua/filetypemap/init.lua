---@class FiletypemapConfig
---@field notify boolean Show notification when mappings are loaded

---@class FiletypemapModule
---@field config FiletypemapConfig
local M = {}

local FILENAME = '.filetypemap'

---@type FiletypemapConfig
local defaults = {
  notify = true,
}

M.config = vim.deepcopy(defaults)

--- Parse a .filetypemap file and return extension mappings
---@param filepath string
---@return table<string, string>
function M.parse(filepath)
  local mappings = {}
  local file = io.open(filepath, 'r')
  if not file then
    return mappings
  end

  for line in file:lines() do
    line = vim.trim(line)
    -- Skip empty lines and comments
    if line ~= '' and not vim.startswith(line, '#') then
      local ext, filetype = line:match '^([^=]+)=(.+)$'
      if ext and filetype then
        mappings[vim.trim(ext)] = vim.trim(filetype)
      end
    end
  end

  file:close()
  return mappings
end

--- Apply extension mappings using vim.filetype.add
---@param mappings table<string, string>
function M.apply(mappings)
  if vim.tbl_isempty(mappings) then
    return
  end

  vim.filetype.add {
    extension = mappings,
  }
end

--- Load .filetypemap from cwd and apply mappings
---@return number count Number of mappings loaded
function M.load()
  local cwd = vim.fn.getcwd()
  local filepath = cwd .. '/' .. FILENAME

  if vim.fn.filereadable(filepath) ~= 1 then
    return 0
  end

  local mappings = M.parse(filepath)
  local count = vim.tbl_count(mappings)

  if count > 0 then
    M.apply(mappings)
    if M.config.notify then
      vim.notify(
        string.format('Loaded %d filetype mapping%s from %s', count, count == 1 and '' or 's', FILENAME),
        vim.log.levels.INFO
      )
    end
  end

  return count
end

--- Setup the plugin with user configuration
---@param opts? FiletypemapConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', defaults, opts or {})

  -- Load mappings on setup
  M.load()

  -- Create user command
  vim.api.nvim_create_user_command('FiletypeMapReload', function()
    M.load()
  end, { desc = 'Reload .filetypemap from current directory' })
end

return M
