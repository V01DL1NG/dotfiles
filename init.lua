-- ║                    Author: Your Name                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

local opt = vim.opt
local g = vim.g
local map = vim.keymap.set

-- Set leader key BEFORE loading plugins
g.mapleader = " "
g.maplocalleader = ","

-- Visual settings
opt.number = true
opt.relativenumber = true
opt.numberwidth = 4
opt.cursorline = true
opt.cursorcolumn = true
opt.textwidth = 80
opt.colorcolumn = "80"
opt.signcolumn = "yes"
opt.showmode = false

-- Tab and indentation
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

-- Search and navigation
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.wildmenu = true
opt.wildmode = "longest:list,full"

-- Behavior and performance
opt.hidden = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.backspace = "indent,eol,start"
opt.termguicolors = true

-- Files and backups
opt.backup = false
opt.swapfile = false
opt.undodir = vim.fn.expand("~/.vim/undo")
opt.undofile = true
vim.fn.mkdir(vim.fn.expand("~/.vim/undo"), "p")

-- ============================================================================
-- PLUGIN MANAGER (lazy.nvim)
-- ============================================================================

-- Bootstrap lazy.nvim if not installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
opt.rtp:prepend(lazypath)

-- Define plugins
local plugins = {
  -- Appearance & Themes
  { "morhetz/gruvbox", priority = 1000 },
  { "folke/tokyonight.nvim", priority = 1000 },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "gruvbox",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
          disabled_filetypes = { "NvimTree", "Telescope" },
        },
        sections = {
          lualine_a = {
            { "mode", fmt = function(str) return str:sub(1, 1) end },
          },
          lualine_b = {
            { "branch", icon = "󰊢" },
            { "diff", symbols = { added = " ", modified = " ", removed = " " } },
          },
          lualine_c = {
            { "filename", path = 1, symbols = { modified = " [+]", readonly = " [RO]" } },
          },
          lualine_x = {
            {
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
            { "encoding" },
            { "fileformat", symbols = { unix = "LF", dos = "CRLF", mac = "CR" } },
            { "filetype", icon_only = false },
          },
          lualine_y = {
            {
              function()
                local word_count = vim.fn.wordcount().words
                return string.format("🔤 %d", word_count)
              end,
              padding = 1,
            },
            { "progress", padding = 1 },
          },
          lualine_z = {
            {
              function()
                local line = vim.fn.line(".")
                local col = vim.fn.col(".")
                return string.format("ℓ %d:%d", line, col)
              end,
              padding = 1,
            },
          },
        },
      })
    end,
  },

  -- File Explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        actions = { open_file = { quit_on_open = false } },
        renderer = {
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = { dotfiles = false },
        git = { enable = true },
      })
    end,
  },

  -- Fuzzy Finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")
      telescope.setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { width = 0.9, height = 0.6 },
        },
      })
    end,
  },

  -- Treesitter for better syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      vim.treesitter.language.register("bash", "sh")
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },

  -- Mason (auto-install LSP servers)
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "pyright", "ts_ls" },
        automatic_installation = true,
      })
    end,
  },

  -- LSP and Completion
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/nvim-cmp", "hrsh7th/cmp-nvim-lsp", "williamboman/mason-lspconfig.nvim" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Lua
      vim.lsp.config.lua_ls = {
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".git" },
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
          },
        },
      }

      -- Python
      vim.lsp.config.pyright = {
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyrightconfig.json", "pyproject.toml", ".git" },
        capabilities = capabilities,
      }

      -- TypeScript/JavaScript
      vim.lsp.config.ts_ls = {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
        root_markers = { "tsconfig.json", "package.json", ".git" },
        capabilities = capabilities,
      }

      vim.lsp.enable({ "lua_ls", "pyright", "ts_ls" })

      -- LSP keybindings (activate when LSP attaches)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          map("n", "gd", vim.lsp.buf.definition, opts)
          map("n", "gr", vim.lsp.buf.references, opts)
          map("n", "K", vim.lsp.buf.hover, opts)
          map("n", "<Leader>rn", vim.lsp.buf.rename, opts)
          map("n", "<Leader>ca", vim.lsp.buf.code_action, opts)
          map("n", "[d", vim.diagnostic.goto_prev, opts)
          map("n", "]d", vim.diagnostic.goto_next, opts)
        end,
      })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  -- Editing & Navigation
  { "tpope/vim-commentary" },
  { "tpope/vim-surround" },
  { "tpope/vim-repeat" },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },
  {
    url = "https://codeberg.org/andyg/leap.nvim",
    config = function()
      vim.keymap.set("n", "s", "<Plug>(leap)")
      vim.keymap.set("n", "S", "<Plug>(leap-from-window)")
      vim.keymap.set({ "x", "o" }, "s", "<Plug>(leap-forward)")
      vim.keymap.set({ "x", "o" }, "S", "<Plug>(leap-backward)")
    end,
  },

  -- Git Integration
  { "tpope/vim-fugitive" },
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "-" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local opts = { buffer = bufnr }
          map("n", "]c", gs.next_hunk, opts)
          map("n", "[c", gs.prev_hunk, opts)
          map("n", "<Leader>hs", gs.stage_hunk, opts)
          map("n", "<Leader>hr", gs.reset_hunk, opts)
          map("n", "<Leader>hb", gs.blame_line, opts)
          map("n", "<Leader>hd", gs.diffthis, opts)
        end,
      })
    end,
  },

  -- Which-key (keybinding popup)
  {
    "folke/which-key.nvim",
    config = function()
      local wk = require("which-key")
      wk.setup({
        delay = 300,
      })
      wk.add({
        { "<Leader>f", group = "Find" },
        { "<Leader>ff", desc = "Find files" },
        { "<Leader>fg", desc = "Live grep" },
        { "<Leader>fb", desc = "Buffers" },
        { "<Leader>fh", desc = "Help tags" },
        { "<Leader>w", desc = "Save" },
        { "<Leader>q", desc = "Quit" },
        { "<Leader>Q", desc = "Force quit" },
        { "<Leader>n", desc = "Toggle file explorer" },
        { "<Leader>/", desc = "Toggle comment" },
        { "<Leader>rn", desc = "Rename symbol" },
        { "<Leader>ca", desc = "Code action" },
        { "<Leader>h",  group = "Git hunks" },
        { "<Leader>hs", desc = "Stage hunk" },
        { "<Leader>hr", desc = "Reset hunk" },
        { "<Leader>hb", desc = "Blame line" },
        { "<Leader>hd", desc = "Diff this" },
      })
    end,
  },

  -- Visual Enhancements
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup()
    end,
  },
  {
    "RRethy/vim-illuminate",
    config = function()
      require("illuminate").configure({
        delay = 250,
      })
    end,
  },
}

-- Load plugins
require("lazy").setup(plugins, {
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
})

-- ============================================================================
-- THEME & COLORS
-- ============================================================================

vim.cmd.colorscheme("gruvbox")
opt.background = "dark"

-- Custom highlights (use GUI colors since termguicolors is enabled)
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#3c3836" })
vim.api.nvim_set_hl(0, "CursorColumn", { bg = "#3c3836" })
vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#3c3836" })

-- ============================================================================
-- KEY MAPPINGS
-- ============================================================================

-- Quick save and quit
map("n", "<Leader>w", ":w<CR>", { noremap = true, silent = true })
map("n", "<Leader>q", ":q<CR>", { noremap = true, silent = true })
map("n", "<Leader>Q", ":q!<CR>", { noremap = true, silent = true })

-- NvimTree toggle
map("n", "<Leader>n", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
map("n", "<Leader>f", ":NvimTreeFocus<CR>", { noremap = true, silent = true })

-- Telescope keybinds
local builtin = require("telescope.builtin")
map("n", "<Leader>ff", builtin.find_files, {})
map("n", "<Leader>fg", builtin.live_grep, {})
map("n", "<Leader>fb", builtin.buffers, {})
map("n", "<Leader>fh", builtin.help_tags, {})

-- Better navigation between windows
map("n", "<C-h>", "<C-w>h", { noremap = true })
map("n", "<C-j>", "<C-w>j", { noremap = true })
map("n", "<C-k>", "<C-w>k", { noremap = true })
map("n", "<C-l>", "<C-w>l", { noremap = true })

-- Disable arrow keys (force hjkl)
map("n", "<Up>", "<Nop>", { noremap = true })
map("n", "<Down>", "<Nop>", { noremap = true })
map("n", "<Left>", "<Nop>", { noremap = true })
map("n", "<Right>", "<Nop>", { noremap = true })

-- Better indentation in visual mode
map("v", "<", "<gv", { noremap = true })
map("v", ">", ">gv", { noremap = true })

-- Comment toggle
map("n", "<Leader>/", ":Commentary<CR>", { noremap = true, silent = true })
map("v", "<Leader>/", ":Commentary<CR>", { noremap = true, silent = true })

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================

local augroup = vim.api.nvim_create_augroup("user_commands", { clear = true })

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = "*",
  callback = function()
    local save_pos = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_pos)
  end,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 100 })
  end,
})

-- ============================================================================
-- FOOTER
-- ============================================================================

-- vim: set foldmethod=marker :

