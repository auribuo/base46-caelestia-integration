--- @class IntegrationOptions 
--- @field path string 
local defaultOpts = {
    path = "~/.local/state/caelestia/scheme.json"
}

--- @class Base46IntegrationPlugin 
local plugin = {}

--- @param optionalOpts IntegrationOptions?
function plugin.setup(optionalOpts)
    local opts = optionalOpts or defaultOpts
    local ffi = require("ffi")

    ffi.cdef [[
            int inotify_init1(int flags);
            int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
            int read(int fd, void *buf, size_t count);
            int close(int fd);
            typedef struct {
              int wd;
              uint32_t mask;
              uint32_t cookie;
              uint32_t len;
              char name[];
            } inotify_event;
        ]]

    local IN_MODIFY = 0x00000002
    local IN_NONBLOCK = 0x800
    local BUF_LEN = 1024

    local path = opts.path and opts.path:gsub("^~", vim.fn.expand("$HOME"))

    --- @param p string
    --- @return string | nil
    local function read_entire_file(p)
        local f = io.open(p, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        return content
    end

    local function write_entire_file(p, content)
        local f = io.open(p, "w")
        if not f then return false end
        f:write(content)
        f:close()
        return true
    end

    if not vim.fn.filereadable(path) then
        vim.notify("File is not readable. " .. path, vim.log.levels.ERROR)
        return
    end

    local stat = vim.loop.fs_stat(path)
    if not stat then
        vim.notify("File does not exist: " .. path, vim.log.levels.ERROR)
        return
    end
    if stat.type ~= "file" then
        vim.notify("Path is not a regular file: " .. path, vim.log.levels.ERROR)
        return
    end

    local function needs_regen(content)
        local current_hfile = vim.fn.stdpath("cache") .. "/base46-caelestia-integration"
        if vim.fn.filereadable(current_hfile) == 0 then
            local h = vim.fn.sha256(content)
            write_entire_file(current_hfile, h)
            return true
        else
            local currenth = read_entire_file(current_hfile)
            if not currenth then return true end
            local h = vim.fn.sha256(currenth)
            if h == currenth then
                return false
            else
                write_entire_file(current_hfile, h)
                return true
            end
        end
    end

    local function gen_theme(content)
        local ok, data = pcall(vim.fn.json_decode, content)
        if not ok or not data or not data.colours then
            vim.notify("Failed to deserialize scheme file" .. path, vim.log.levels.ERROR)
            return
        end
        local c = data.colours
        local base_30_map = {
            white = c.text,
            black = c.base,
            darker_black = c.crust,
            black2 = c.surface1,
            one_bg = c.surface2,
            one_bg2 = c.overlay0,
            one_bg3 = c.overlay1,
            grey = c.surfaceVariant,
            grey_fg = c.subtext0,
            grey_fg2 = c.subtext1,
            light_grey = c.onSurfaceVariant,
            red = c.red,
            baby_pink = c.pink,
            pink = c.mauve,
            line = c.surface1,
            green = c.green,
            vibrant_green = c.success,
            nord_blue = c.sapphire,
            blue = c.blue,
            seablue = c.sky,
            yellow = c.yellow,
            sun = c.peach,
            purple = c.mauve,
            dark_purple = c.maroon,
            teal = c.teal,
            orange = c.peach,
            cyan = c.teal,
            statusline_bg = c.surfaceContainerHigh,
            lightbg = c.surfaceContainerHighest,
            pmenu_bg = c.primary,
            folder_bg = c.primaryContainer,
        }

        local base_16_map = {
            base00 = c.surface,
            base01 = c.surfaceContainer,
            base02 = c.surfaceContainerLow,
            base03 = c.onSurfaceVariant,
            base04 = c.surfaceContainerHigh,
            base05 = c.onSurface,
            base06 = c.onPrimary,
            base07 = c.surfaceContainerHighest,
            base08 = c.red,
            base09 = c.peach,
            base0A = c.yellow,
            base0B = c.green,
            base0C = c.teal,
            base0D = c.blue,
            base0E = c.mauve,
            base0F = c.maroon,
        }

        local lines = {
            '---@type Base46Table',
            'local M = {',
            '    base_30 = {',
        }

        for k, v in pairs(base_30_map) do
            table.insert(lines, string.format('        %s = "#%s",', k, v:gsub("^#", "")))
        end
        table.insert(lines, '    },')
        table.insert(lines, '    base_16 = {')

        for k, v in pairs(base_16_map) do
            table.insert(lines, string.format('        %s = "#%s",', k, v:gsub("^#", "")))
        end

        table.insert(lines, '    },')
        table.insert(lines, string.format('    type = "%s",', data.mode or "dark"))
        table.insert(lines, '    add_hl = {},')
        table.insert(lines, '    polish_hl = {},')
        table.insert(lines, '}')
        table.insert(lines, 'M = require("base46").override_theme(M, "caelestia")')
        table.insert(lines, 'return M')
        table.insert(lines, '')

        local output = table.concat(lines, "\n")
        local output_path = vim.fn.stdpath("config") .. "/lua/themes/caelestia.lua"
        local of = io.open(output_path, "w")
        if not of then
            vim.notify("Failed to open dynamic theme file: " .. output_path)
            return
        end
        of:write(output)
        of:close()

        local m = assert(dofile(output_path))
        require("nvconfig").base46.theme = 'caelestia'
        require("base46").override_theme(m, "caelestia")
        require("base46").load_all_highlights()
    end

    local function on_file_change()
        local contents = read_entire_file(path)
        if contents then
            vim.schedule(function()
                if needs_regen(contents) then
                    vim.notify("Regen theme", vim.log.levels.INFO)
                    gen_theme(contents)
                end
                vim.notify("Theme changed!", vim.log.levels.INFO)
            end)
        end
    end

    local function start_watching()
        local fd = ffi.C.inotify_init1(IN_NONBLOCK)
        if fd < 0 then
            vim.notify("Failed to initialize notify", vim.log.levels.ERROR)
            return
        end

        local wd = ffi.C.inotify_add_watch(fd, path, IN_MODIFY)
        if wd < 0 then
            vim.notify("Failed to watch scheme file: " .. path, vim.log.levels.ERROR)
            return
        end

        vim.loop.new_timer():start(0, 1000, function()
            local buffer = ffi.new("uint8_t[?]", BUF_LEN)
            local bytes = ffi.C.read(fd, buffer, BUF_LEN)
            if bytes > 0 then
                on_file_change()
            end
        end)
    end

    local contents = read_entire_file(path)
    print(needs_regen(contents))
    if contents and needs_regen(contents) then
        gen_theme(contents)
    end
    start_watching()
end

return plugin
