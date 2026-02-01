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
3. Registers them using `vim.filetype.add()`

This integrates with Neovim's built-in filetype detection system, so LSP, treesitter, and syntax highlighting all work correctly.

## License

MIT
