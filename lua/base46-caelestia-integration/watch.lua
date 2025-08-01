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

local M = {}
function M.watch_file(path, on_change)
    local IN_MODIFY = 0x00000002
    local IN_NONBLOCK = 0x800
    local BUF_LEN = 1024

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
            vim.schedule(on_change)
        end
    end)
end

return M
