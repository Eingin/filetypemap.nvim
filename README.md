# filetypemap.nvim

A Neovim plugin that reads project-local `.filetypemap` files to define custom filetype mappings for file extensions.

## Use Case

Some projects use custom file extensions that Neovim doesn't recognize. For example, systemd quadlet files use `.container`, `.network`, `.timer` extensions. Instead of configuring these globally, you can drop a `.filetypemap` file in your project root.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'yourusername/filetypemap.nvim',
  event = 'VimEnter',
  opts = {},
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'yourusername/filetypemap.nvim',
  config = function()
    require('filetypemap').setup()
  end
}
```

## Configuration

```lua
require('filetypemap').setup({
  -- Show notification when mappings are loaded (default: true)
  notify = true,
})
```

## Usage

Create a `.filetypemap` file in your project root:

```ini
# Systemd quadlet files
container=systemd
network=systemd
timer=systemd

# Custom formats
myext=json
```

### Format

- One mapping per line: `extension=filetype`
- Lines starting with `#` are comments
- Empty lines are ignored
- Whitespace around `=` is trimmed

### Commands

| Command | Description |
|---------|-------------|
| `:FiletypeMapReload` | Reload `.filetypemap` from current directory |

## How It Works

On setup, the plugin:

1. Checks if `.filetypemap` exists in `vim.fn.getcwd()`
2. Parses extension mappings from the file
3. Sets filetypes for matching buffers via autocmds

When you change directories (`DirChanged` event), the plugin automatically:

1. Loads the new directory's `.filetypemap` (if present)
2. Resets any open buffers that were affected by old mappings back to Neovim's default detection
3. Applies new mappings to relevant open buffers

This ensures mappings are scoped to the current directory - switching projects won't leave stale mappings behind.

## Development

### Running Tests

Tests use [mini.test](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) from mini.nvim.

```bash
# Run all tests (downloads mini.nvim on first run)
make test

# Run a specific test file
FILE=tests/test_filetypemap.lua make test_file

# Clean dependencies
make clean
```

## License

MIT
