-- ==========================================
-- LINUS STYLE (Linux Kernel Coding Standard)
-- ==========================================
vim.opt.wrap = false
vim.opt.expandtab = false      
vim.opt.tabstop = 8            
vim.opt.softtabstop = 8
vim.opt.shiftwidth = 8
vim.opt.cindent = true         
vim.opt.fixendofline = true    
vim.opt.number = true          
vim.opt.numberwidth = 4
vim.opt.signcolumn = "yes"     
vim.opt.clipboard = "unnamedplus" 
vim.opt.termguicolors = true   
vim.opt.fillchars = { eob = " " } -- No more ~ lines
vim.g.mapleader = " "

-- ==========================================
-- NAVIGATION (Tree <-> Code <-> Terminal)
-- ==========================================
vim.keymap.set('n', '<C-n>', ':NvimTreeToggle<CR>', { silent = true })
vim.keymap.set('n', '<C-h>', '<C-w>h', { silent = true })
vim.keymap.set('n', '<C-l>', '<C-w>l', { silent = true })
vim.keymap.set('n', '<leader>x', ':bp | bd #<CR>', { silent = true })
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { silent = true })

-- ==========================================
-- PLUGINS (Lazy.nvim)
-- ==========================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- THEME (Moonfly)
    {
        "bluz71/vim-moonfly-colors",
        name = "moonfly",
        priority = 1000,
        config = function()
            vim.g.moonflyNormalFloat = true
            vim.cmd.colorscheme "moonfly"
            vim.cmd([[
                highlight DiagnosticSignError guifg=#FF0000
                highlight DiagnosticSignWarn  guifg=#FFFF00
            ]])
        end,
    },

    -- SYNTAX (Treesitter)
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            local status, ts = pcall(require, "nvim-treesitter.configs")
            if not status then return end
            ts.setup({
                ensure_installed = { "c", "asm", "lua", "vim", "python" },
                highlight = { enable = true },
            })
        end,
    },

    -- LSP SUPPORT (Native 0.11+ Optimized)
    {
        "neovim/nvim-lspconfig",
        dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({ ensure_installed = { "clangd" } })

            -- Native config prevents deprecation warnings
            vim.lsp.config('clangd', {
                cmd = { "clangd", "--background-index", "--fallback-style=linux" },
            })
            vim.lsp.enable('clangd')

            vim.diagnostic.config({ virtual_text = false, signs = true, underline = true })

            -- Hover details popup
            vim.api.nvim_create_autocmd("CursorHold", {
                callback = function()
                    vim.diagnostic.open_float(nil, { focusable = false, scope = "line", border = "rounded" })
                end,
            })
        end
    },

    -- FILE TREE (Project Name Only)
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                view = { width = 30 },
                renderer = {
                    root_folder_label = ":t", -- THIS SHOWS ONLY THE PROJECT NAME
                    highlight_git = true,
                },
                update_focused_file = { enable = true }, -- Syncs tree with the file you are editing
            })
        end,
    },

    -- TERMINAL (Right Side & Sync Folder)
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        config = function()
            require("toggleterm").setup({
                size = 60,
                open_mapping = [[<C-t>]],
                direction = 'vertical',
                shade_terminals = true,
                start_in_insert = true,
                -- Ensures terminal starts in your project folder
                dir = "git_dir", 
            })
        end
    },

    -- TABS (Bufferline)
    {
        "akinsho/bufferline.nvim",
        config = function()
            require("bufferline").setup({
                options = {
                    offsets = { { filetype = "NvimTree", text = "File Explorer", separator = true } }
                }
            })
            vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>")
            vim.keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>")
        end
    },

    -- UTILS
    { "windwp/nvim-autopairs", config = true },
    { "nvim-telescope/telescope.nvim", dependencies = "nvim-lua/plenary.nvim" },

})

-- ==========================================
-- SMART AUTO-COMMANDS
-- ==========================================

-- 1. Auto-close Neovim if only the Tree is left
vim.api.nvim_create_autocmd("BufEnter", {
  nested = true,
  callback = function()
    if #vim.api.nvim_list_wins() == 1 and vim.api.nvim_buf_get_name(0):match("NvimTree_") ~= nil then
      vim.cmd("quit")
    end
  end
})

-- 2. Define High-Contrast Signs
local signs = { Error = "E", Warn = "W", Hint = "H", Info = "I" }
for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- ==========================================
-- CLAUDE AI
-- ==========================================

vim.g.claude_model = "claude-sonnet-4-6"

local claude_models = { "claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5-20251001" }

local function strip_fences(lines)
    if #lines == 0 then return lines end
    local s, e = 1, #lines
    if lines[s]:match("^```") then s = s + 1 end
    if lines[e]:match("^```") then e = e - 1 end
    local out = {}
    for i = s, e do out[#out + 1] = lines[i] end
    return out
end

local function show_diff(bufnr, s_line, e_line, orig, new_lines, selection)
    local W = math.min(math.floor(vim.o.columns * 0.92), 130)
    local sep = string.rep("─", W - 4)
    local content = {}
    local hl = {}

    content[#content+1] = "  [a] Accept    [r] Reject    [e] Edit"
    content[#content+1] = sep

    for _, l in ipairs(orig) do
        content[#content+1] = "- " .. l
        hl[#hl+1] = { #content - 1, "DiffDelete" }
    end

    content[#content+1] = sep

    for _, l in ipairs(new_lines) do
        content[#content+1] = "+ " .. l
        hl[#hl+1] = { #content - 1, "DiffAdd" }
    end

    local H = math.min(#content + 2, math.floor(vim.o.lines * 0.85))
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = W, height = H,
        row = math.floor((vim.o.lines - H) / 2),
        col = math.floor((vim.o.columns - W) / 2),
        style = "minimal", border = "rounded",
        title = " Claude Diff ", title_pos = "center",
    })

    local ns = vim.api.nvim_create_namespace("claude_diff")
    for _, h in ipairs(hl) do
        vim.api.nvim_buf_add_highlight(buf, ns, h[2], h[1], 0, -1)
    end

    local function close() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
    local o = { buffer = buf, nowait = true, silent = true }

    vim.keymap.set('n', 'a', function()
        close()
        vim.schedule(function() vim.api.nvim_buf_set_lines(bufnr, s_line - 1, e_line, false, new_lines) end)
    end, o)

    vim.keymap.set('n', 'r', close, o)
    vim.keymap.set('n', '<Esc>', close, o)
    vim.keymap.set('n', 'q', close, o)

    vim.keymap.set('n', 'e', function()
        close()
        vim.schedule(function() vim.cmd("ClaudePrompt") end)
    end, o)

    -- store for re-edit
    vim.b[buf]._claude = { bufnr = bufnr, s_line = s_line, e_line = e_line, orig = orig, selection = selection }
end

local function call_claude(model, prompt, on_done, extra_flags)
    local out = {}
    local cmd = { "claude", "--model", model }
    if extra_flags then vim.list_extend(cmd, extra_flags) end
    vim.list_extend(cmd, { "-p", prompt })
    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, data) if data then vim.list_extend(out, data) end end,
        on_exit = function(_, code)
            while #out > 0 and out[#out] == "" do table.remove(out) end
            on_done(out, code)
        end,
    })
end

local function get_context(bufnr)
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local file_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local file_content = table.concat(file_lines, "\n")

    local cwd = vim.fn.getcwd()
    local git = ""
    local branch = vim.trim(vim.fn.system("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --abbrev-ref HEAD 2>/dev/null"))
    if branch ~= "" and not branch:match("^fatal") then
        local status = vim.fn.system("git -C " .. vim.fn.shellescape(cwd) .. " status --short 2>/dev/null")
        git = "branch: " .. branch .. "\n" .. status
    end

    return filepath, file_content, git
end

local function show_spinner()
    local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local frame = 1
    local W, H = 26, 1
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = W, height = H,
        row = math.floor((vim.o.lines - H) / 2),
        col = math.floor((vim.o.columns - W) / 2),
        style = "minimal", border = "rounded",
        title = " Claude ", title_pos = "center",
    })
    local timer = vim.uv.new_timer()
    timer:start(0, 80, vim.schedule_wrap(function()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "  " .. frames[frame] .. "  Generating..." })
        vim.bo[buf].modifiable = false
        frame = (frame % #frames) + 1
    end))
    return function()
        timer:stop()
        timer:close()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end
end

local function show_model_selector(on_done)
    local W, H = 36, #claude_models
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    local items = {}
    local current = 1
    for i, m in ipairs(claude_models) do
        items[i] = (m == vim.g.claude_model and "  » " or "    ") .. m
        if m == vim.g.claude_model then current = i end
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, items)
    vim.bo[buf].modifiable = false
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = W, height = H,
        row = math.floor((vim.o.lines - H) / 2),
        col = math.floor((vim.o.columns - W) / 2),
        style = "minimal", border = "rounded",
        title = " Claude Model ", title_pos = "center",
    })
    local ns = vim.api.nvim_create_namespace("claude_model_sel")
    local function highlight(idx)
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, ns, "Visual", idx - 1, 0, -1)
        vim.api.nvim_win_set_cursor(win, { idx, 0 })
    end
    highlight(current)
    local function close() if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end end
    local o = { buffer = buf, nowait = true, silent = true }
    vim.keymap.set('n', 'j', function()
        current = (current % #claude_models) + 1
        highlight(current)
    end, o)
    vim.keymap.set('n', 'k', function()
        current = ((current - 2 + #claude_models) % #claude_models) + 1
        highlight(current)
    end, o)
    vim.keymap.set('n', '<CR>', function()
        close()
        on_done(claude_models[current])
    end, o)
    vim.keymap.set('n', '<Esc>', close, o)
    vim.keymap.set('n', 'q', close, o)
end

local function make_title()
    return " Claude Edit  │  model: " .. vim.g.claude_model .. "  │  [m] change  [Enter] send  [Esc] cancel "
end

local function show_prompt(bufnr, s_line, e_line, orig, selection)
    local W = math.min(72, math.floor(vim.o.columns * 0.75))
    local H = 3
    local pbuf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, {""})
    vim.bo[pbuf].bufhidden = "wipe"

    local pwin = vim.api.nvim_open_win(pbuf, true, {
        relative = "editor",
        width = W, height = H,
        row = math.floor((vim.o.lines - H) / 2),
        col = math.floor((vim.o.columns - W) / 2),
        style = "minimal", border = "rounded",
        title = make_title(), title_pos = "center",
    })

    vim.cmd("startinsert")

    local function close() if vim.api.nvim_win_is_valid(pwin) then vim.api.nvim_win_close(pwin, true) end end

    local function submit()
        local lines = vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)
        local instr = vim.trim(table.concat(lines, "\n"))
        close()
        if instr == "" then return end
        local filepath, file_content, git = get_context(bufnr)
        local ctx = ""
        if git ~= "" then
            ctx = ctx .. "Git status:\n" .. git .. "\n\n"
        end
        ctx = ctx .. "File: " .. filepath .. "\n"
        ctx = ctx .. file_content .. "\n\n"
        ctx = ctx .. "The following lines (" .. s_line .. "-" .. e_line .. ") are selected for editing:\n"
        ctx = ctx .. selection .. "\n\n"
        ctx = ctx .. "Instruction: " .. instr .. "\n\n"
        ctx = ctx .. "Reply with ONLY the replacement code for the selected lines. No explanations. No markdown. No code fences. Raw code only."
        local stop_spinner = show_spinner()
        call_claude(vim.g.claude_model, ctx, function(new_lines, code)
            vim.schedule(function()
                stop_spinner()
                if code ~= 0 or #new_lines == 0 then
                    vim.notify("Claude failed", vim.log.levels.ERROR)
                    return
                end
                new_lines = strip_fences(new_lines)
                show_diff(bufnr, s_line, e_line, orig, new_lines, selection)
            end)
        end)
    end

    local o = { buffer = pbuf, nowait = true, silent = true }
    vim.keymap.set('i', '<CR>', function() vim.cmd("stopinsert") submit() end, o)
    vim.keymap.set('n', '<CR>', submit, o)
    vim.keymap.set({'i','n'}, '<Esc>', function() vim.cmd("stopinsert") close() end, o)
    vim.keymap.set('n', 'm', function()
        show_model_selector(function(choice)
            vim.g.claude_model = choice
            vim.api.nvim_win_set_config(pwin, { title = make_title(), title_pos = "center" })
            vim.cmd("startinsert")
        end)
    end, o)
end

-- <leader>ce: Claude edit selection (visual)
vim.keymap.set('v', '<leader>ae', function()
    vim.cmd('normal! "zy')
    local sel = vim.fn.getreg('z')
    local bufnr = vim.api.nvim_get_current_buf()
    local s_line = vim.fn.line("'<")
    local e_line = vim.fn.line("'>")
    local orig = vim.split(sel, "\n", { plain = true })
    while #orig > 0 and orig[#orig] == "" do table.remove(orig) end
    show_prompt(bufnr, s_line, e_line, orig, sel)
end, { desc = "Claude edit selection" })

-- =============================================
-- PROJECT AI CHAT
-- =============================================

local chat_history = {}
local chat_buf = nil
local chat_win = nil

local function chat_render()
    if not (chat_buf and vim.api.nvim_buf_is_valid(chat_buf)) then return end
    vim.bo[chat_buf].modifiable = true
    local lines = { "" }
    for _, msg in ipairs(chat_history) do
        if msg.role == "user" then
            table.insert(lines, "  You  ──────────────────────────────────────")
        else
            table.insert(lines, "  Claude  ────────────────────────────────────")
        end
        for _, l in ipairs(vim.split(msg.content, "\n", { plain = true })) do
            table.insert(lines, "  " .. l)
        end
        table.insert(lines, "")
    end
    vim.api.nvim_buf_set_lines(chat_buf, 0, -1, false, lines)
    vim.bo[chat_buf].modifiable = false
    local ns = vim.api.nvim_create_namespace("claude_chat_hl")
    vim.api.nvim_buf_clear_namespace(chat_buf, ns, 0, -1)
    for i, l in ipairs(lines) do
        if l:match("^  You  ") then
            vim.api.nvim_buf_add_highlight(chat_buf, ns, "Title", i - 1, 0, -1)
        elseif l:match("^  Claude  ") then
            vim.api.nvim_buf_add_highlight(chat_buf, ns, "DiffAdd", i - 1, 0, -1)
        end
    end
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
        vim.api.nvim_win_set_cursor(chat_win, { vim.api.nvim_buf_line_count(chat_buf), 0 })
    end
end

local function chat_send(message)
    table.insert(chat_history, { role = "user", content = message })
    chat_render()

    local cwd = vim.fn.getcwd()
    local project = cwd:match("([^/]+)$") or cwd
    local prompt = "You are a coding assistant for the project '" .. project .. "' at " .. cwd .. ".\n"
    prompt = prompt .. "Answer questions about the code. Be concise.\n"

    local branch = vim.trim(vim.fn.system("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --abbrev-ref HEAD 2>/dev/null"))
    if branch ~= "" and not branch:match("^fatal") then
        local status = vim.fn.system("git -C " .. vim.fn.shellescape(cwd) .. " status --short 2>/dev/null")
        prompt = prompt .. "\nGit branch: " .. branch .. "\nGit status:\n" .. status
    end

    prompt = prompt .. "\n\nConversation so far:\n"
    for _, msg in ipairs(chat_history) do
        prompt = prompt .. (msg.role == "user" and "User: " or "Assistant: ") .. msg.content .. "\n"
    end
    prompt = prompt .. "Assistant:"

    local stop = show_spinner()
    call_claude(vim.g.claude_model, prompt, function(out, code)
        vim.schedule(function()
            stop()
            if code ~= 0 or #out == 0 then
                vim.notify("Claude chat failed", vim.log.levels.ERROR)
                return
            end
            table.insert(chat_history, { role = "assistant", content = table.concat(out, "\n") })
            chat_render()
        end)
    end, { "--dangerously-skip-permissions" })
end

local function chat_open()
    -- Toggle: close if already open
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
        vim.api.nvim_win_close(chat_win, true)
        chat_win = nil
        return
    end

    local cwd = vim.fn.getcwd()
    local project = cwd:match("([^/]+)$") or cwd
    local TW = math.min(math.floor(vim.o.columns * 0.88), 120)
    local TH = math.floor(vim.o.lines * 0.82)
    local chat_H = TH - 5
    local input_H = 3
    local row = math.floor((vim.o.lines - TH) / 2)
    local col = math.floor((vim.o.columns - TW) / 2)

    -- Reuse or create chat buffer (keeps history alive)
    if not (chat_buf and vim.api.nvim_buf_is_valid(chat_buf)) then
        chat_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[chat_buf].bufhidden = "hide"
    end
    chat_win = vim.api.nvim_open_win(chat_buf, false, {
        relative = "editor",
        width = TW, height = chat_H,
        row = row, col = col,
        style = "minimal", border = "rounded",
        title = "  Project Chat: " .. project .. "  │  [Esc/q] close  [c] clear history ",
        title_pos = "center",
    })
    vim.wo[chat_win].wrap = true
    vim.wo[chat_win].linebreak = true
    chat_render()

    -- Input window below chat
    local ibuf = vim.api.nvim_create_buf(false, true)
    vim.bo[ibuf].bufhidden = "wipe"
    local function input_title()
        return "  " .. vim.g.claude_model .. "  │  [Enter] send  [m] model  [c] clear  [Esc] close "
    end
    local iwin = vim.api.nvim_open_win(ibuf, true, {
        relative = "editor",
        width = TW, height = input_H,
        row = row + chat_H + 1, col = col,
        style = "minimal", border = "rounded",
        title = input_title(), title_pos = "center",
    })
    vim.cmd("startinsert")

    local function close()
        if vim.api.nvim_win_is_valid(iwin) then vim.api.nvim_win_close(iwin, true) end
        if chat_win and vim.api.nvim_win_is_valid(chat_win) then vim.api.nvim_win_close(chat_win, true) end
        chat_win = nil
    end

    local io = { buffer = ibuf, nowait = true, silent = true }
    vim.keymap.set('i', '<CR>', function()
        vim.cmd("stopinsert")
        local msg = vim.trim(table.concat(vim.api.nvim_buf_get_lines(ibuf, 0, -1, false), "\n"))
        if msg == "" then return end
        vim.api.nvim_buf_set_lines(ibuf, 0, -1, false, { "" })
        chat_send(msg)
        vim.cmd("startinsert")
    end, io)
    vim.keymap.set({'i','n'}, '<Esc>', function() vim.cmd("stopinsert") close() end, io)
    vim.keymap.set('n', 'c', function()
        chat_history = {}
        chat_render()
        vim.cmd("startinsert")
    end, io)
    vim.keymap.set('n', 'm', function()
        show_model_selector(function(choice)
            vim.g.claude_model = choice
            if vim.api.nvim_win_is_valid(iwin) then
                vim.api.nvim_win_set_config(iwin, { title = input_title(), title_pos = "center" })
            end
            vim.cmd("startinsert")
        end)
    end, io)

    local co = { buffer = chat_buf, nowait = true, silent = true }
    vim.keymap.set('n', '<Esc>', close, co)
    vim.keymap.set('n', 'q', close, co)
end

vim.keymap.set('n', '<leader>ac', chat_open, { desc = "Project AI chat" })

-- <leader>am: Claude model selector
vim.keymap.set('n', '<leader>am', function()
    show_model_selector(function(choice)
        vim.g.claude_model = choice
        vim.notify("Claude model: " .. choice)
    end)
end, { desc = "Claude model selector" })
