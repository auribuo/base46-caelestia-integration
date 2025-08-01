local M = {}
--- @param path string The path to the file
--- @return string Returns the read content
function M.read_entire_file(path)
    local f = io.open(path, "r")
    if not f then error("read_entire_file: Failed to open file: " .. path) end
    local content = f:read("*a")
    f:close()
    return content
end

--- @param path string The path to the file
--- @param content string The contents to write to the file
function M.write_entire_file(path, content)
    local f = io.open(path, "w")
    if not f then error("write_entire_file: Failed to open file: " .. path) end
    f:write(content)
    f:close()
    return true
end

--- @param path string The path to the file
--- @return table The table read from the json file
function M.read_scheme(path)
    local content = M.read_entire_file(path)
    local ok, data = pcall(vim.fn.json_decode, content)
    if not ok or not data then
        error("read_scheme: Failed to deserialize scheme file: " .. data)
    end
    return data
end

return M
