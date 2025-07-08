local fs = require("filesystem")
local utils = {}

function utils.uuid()
    local t = ""
    for _ = 1, 4 do
        t = t .. string.format("%04X", math.random(0, 0xFFFF))
    end
    return t
end

function utils.log(text)
    if not fs.exists("/server") then
        fs.makeDirectory("/server")
    end

    local f = io.open("/server/log.txt", "a")
    if f then
        f:write("[" .. os.date() .. "] " .. text .. "\n")
        f:close()
    else
        -- fallback to console if file can't be opened
        print("Log error: could not open /server/log.txt")
        print("[" .. os.date() .. "] " .. text)
    end
end

return utils