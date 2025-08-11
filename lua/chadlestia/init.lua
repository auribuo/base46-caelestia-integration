local watch = require("chadlestia.watch")
local fshelper = require("chadlestia.fshelper")

--- @class Base46IntegrationPluginOptions
--- @field path string
--- @field name string
--- @field variants boolean
--- @field notify boolean
--- @field local_theme boolean
local default_opts = {
    path = "~/.local/state/caelestia/scheme.json",
    name = "caelestia",
    variants = false,
    notify = false,
    local_theme = false
}

--- @param user Base46IntegrationPluginOptions?
--- @param default Base46IntegrationPluginOptions
--- @return Base46IntegrationPluginOptions
local function merge_configs(user, default)
    if not user then return default end
    for k, v in pairs(user) do
        if v ~= nil then
            default[k] = v
        end
    end
    return default
end

--- @param data table
--- @param variants boolean
--- @return Base46Table, string
local function gen_theme(data, variants)
    local c = data.colours

    --- @type Base46Table
    local t = {
        base_30 = {
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
        },

        base_16 = {
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
        },
        type = data.mode,
        add_hl = {},
        polish_hl = {}
    }

    local tname = data.name
    if variants then
        tname = tname .. "-" .. data.mode
    end
    return t, tname
end

--- @param t Base46Table
--- @param name string
--- @return string
local function serialize_theme(t, name)
    local lines = {
        '---@type Base46Table',
        'local M = {',
        '    base_30 = {',
    }

    for k, v in pairs(t.base_30) do
        table.insert(lines, string.format('        %s = "#%s",', k, v:gsub("^#", "")))
    end
    table.insert(lines, '    },')
    table.insert(lines, '    base_16 = {')

    for k, v in pairs(t.base_16) do
        table.insert(lines, string.format('        %s = "#%s",', k, v:gsub("^#", "")))
    end

    table.insert(lines, '    },')
    table.insert(lines, string.format('    type = "%s",', t.type))
    table.insert(lines, '    add_hl = {},')
    table.insert(lines, '    polish_hl = {},')
    table.insert(lines, '}')
    table.insert(lines, string.format('M = require("base46").override_theme(M, "%s")', name, t.type))
    table.insert(lines, 'return M')
    table.insert(lines, '')

    return table.concat(lines, "\n")
end

local function gen_theme_file(path, opts)
    local scheme_data = fshelper.read_scheme(path)
    local theme, theme_name_part = gen_theme(scheme_data, opts.variants)
    local theme_name = opts.name .. "-" .. theme_name_part
    local theme_file_content = serialize_theme(theme, theme_name)
    local theme_file_path
    if opts.local_theme then
        theme_file_path = vim.fn.stdpath("config") .. "/lua/themes/" .. theme_name .. ".lua"
    else
        theme_file_path = vim.fn.stdpath("data") .. "/lazy/base46/lua/base46/themes/" .. theme_name .. ".lua"
    end
    fshelper.write_entire_file(theme_file_path, theme_file_content)
    return { theme_file_path = theme_file_path, theme_name = theme_name }
end

--- @class Base46IntegrationPlugin
local plugin = {}

--- @param optional_opts Base46IntegrationPluginOptions?
function plugin.setup(optional_opts)
    local opts = merge_configs(optional_opts, default_opts)

    local path = opts.path and opts.path:gsub("^~", vim.fn.expand("$HOME"))

    local function on_file_change()
        local ok, result = pcall(gen_theme_file, path, opts.name, opts.variants)
        if not ok then
            vim.notify("Failed to generate theme: " .. result, vim.log.levels.ERROR)
            return
        end

        require("base46").load_all_highlights()
        require("nvchad.utils").reload()
        if opts.notify then
            vim.notify("Theme change detected: " .. result.theme_name, vim.log.levels.INFO)
        end
    end

    on_file_change()
    watch.watch_file(path, on_file_change)
end

return plugin
