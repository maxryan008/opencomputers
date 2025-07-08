local utils = {}

function utils.uuid()
    local t = ""
    for _ = 1, 4 do
        t = t .. string.format("%04X", math.random(0, 0xFFFF))
    end
    return t
end

function utils.log(text)
    local f = io.open("/server/log.txt", "a")
    f:write("[" .. os.date() .. "] " .. text .. "\n")
    f:close()
end

return utils
