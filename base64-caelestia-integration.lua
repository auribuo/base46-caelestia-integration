return {
    "auribuo/base64-caelestia-integration",
    lazy = false,
    dev = {true},
    opts = {
        path = "~/.local/state/caelestia/scheme.json"
    },
    config = function(_, opts)
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

        local function read_entire_file()
            local f = io.open(path, "r")
            if not f then return nil end
            local content = f:read("*a")
            f:close()
            return content
        end

        local function on_file_change()
            local contents = read_entire_file()
            if contents then
                vim.schedule(function()
                    vim.notify("File changed!", vim.log.levels.INFO)
                end)
            end
        end

        local function start_watching()
            local fd = ffi.C.inotify_init1(IN_NONBLOCK)
            if fd < 0 then
                vim.notify("Failed to watch scheme file " .. path, vim.log.levels.ERROR)
                return
            end

            local wd = ffi.C.inotify_add_watch(fd, path, IN_MODIFY)
            if wd < 0 then
                vim.notify("Failed to watch scheme file " .. path, vim.log.levels.ERROR)
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

        start_watching()
    end,
}
