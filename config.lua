-- Opções gerais
vim.opt.relativenumber = true
vim.opt.wrap = true
vim.opt.clipboard = "unnamedplus"
lvim.transparent_window = true
lvim.format_on_save.enabled = false
lvim.format_on_save.pattern = { "*.go" }
-- Desabilitar highlight do Treesitter (para evitar bugs recentes)
lvim.builtin.treesitter.highlight.enable = true
lvim.keys.normal_mode["<C-f>"] = "<cmd>Telescope current_buffer_fuzzy_find<CR>"

-- Plugins
lvim.plugins = {
  "ChristianChiarulli/swenv.nvim",
  "stevearc/dressing.nvim",
  "mfussenegger/nvim-dap-python",
  "nvim-neotest/neotest",
  "nvim-neotest/neotest-python",
  "nvim-neotest/nvim-nio",
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },
}

-- Instalação de linguagens pelo Mason (desabilitada para evitar conflitos)
lvim.lsp.installer.setup.automatic_installation = false

-- =====================================
-- PYTHON SETUP (com jedi_language_server)
-- =====================================
vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "pyright" }) -- não usar pyright
require("lvim.lsp.manager").setup("jedi_language_server", {
  filetypes = { "python" }
})

-- DAP para Python
lvim.builtin.dap.active = true
local mason_path = vim.fn.glob(vim.fn.stdpath("data") .. "/mason/")
pcall(function()
  require("dap-python").setup(mason_path .. "packages/debugpy/venv/bin/python")
end)

-- Neotest para Python
require("neotest").setup({
  adapters = {
    require("neotest-python")({
      dap = {
        justMyCode = false,
        console = "integratedTerminal",
      },
      args = { "--log-level", "DEBUG", "--quiet" },
      runner = "pytest",
    }),
  },
})

-- Atalhos para Neotest
lvim.builtin.which_key.mappings["dm"] = {
  "<cmd>lua require('neotest').run.run()<cr>", "Test Method"
}
lvim.builtin.which_key.mappings["dM"] = {
  "<cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", "Test Method DAP"
}
lvim.builtin.which_key.mappings["df"] = {
  "<cmd>lua require('neotest').run.run({vim.fn.expand('%')})<cr>", "Test Class"
}
lvim.builtin.which_key.mappings["dF"] = {
  "<cmd>lua require('neotest').run.run({vim.fn.expand('%'), strategy = 'dap'})<cr>", "Test Class DAP"
}
lvim.builtin.which_key.mappings["dS"] = {
  "<cmd>lua require('neotest').summary.toggle()<cr>", "Test Summary"
}

-- =====================================
-- GOLANG SETUP
-- =====================================
-- Treesitter
lvim.builtin.treesitter.highlight.enable = true
lvim.builtin.treesitter.ensure_installed = {
  "go",
  "python",
}
lvim.builtin.illuminate.active = false

-- gopls (só pra Go)
require("lvim.lsp.manager").setup("gopls", {
  filetypes = { "go", "gomod" },
})

-- Formatador para Go
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup({
  {
    command = "goimports",
    filetypes = { "go" },
  },
})

-- Linter para Go
local linters = require "lvim.lsp.null-ls.linters"
linters.setup({
  {
    command = "golangci-lint",
    filetypes = { "go" },
  },
})

-- DAP para Go
local dap = require("dap")
dap.adapters.go = function(callback, _)
  local stdout = vim.loop.new_pipe(false)
  local handle
  local pid_or_err
  local port = 38697
  local opts = {
    stdio = { nil, stdout },
    args = { "dap", "-l", "127.0.0.1:" .. port },
    detached = true,
  }
  handle, pid_or_err = vim.loop.spawn("dlv", opts, function(code)
    stdout:close()
    handle:close()
    if code ~= 0 then
      print("dlv exited with code", code)
    end
  end)
  assert(handle, "Error running dlv: " .. tostring(pid_or_err))
  stdout:read_start(function(err, chunk)
    assert(not err, err)
    if chunk then
      vim.schedule(function()
        require("dap.repl").append(chunk)
      end)
    end
  end)
  vim.defer_fn(function()
    callback({ type = "server", host = "127.0.0.1", port = port })
  end, 100)
end

dap.configurations.go = {
  {
    type = "go",
    name = "Debug",
    request = "launch",
    program = "${file}",
  },
  {
    type = "go",
    name = "Debug test",
    request = "launch",
    mode = "test",
    program = "${file}",
  },
  {
    type = "go",
    name = "Debug test (go.mod)",
    request = "launch",
    mode = "test",
    program = "./${relativeFileDirname}",
  },
}
