local serialization = require("serialization")
local fs = require("filesystem")

local data = {}

function data.load(file, default)
    if not fs.exists(file) then return default end
    local f = io.open(file, "r")
    local content = f:read("*a")
    f:close()
    return serialization.unserialize(content) or default
end

function data.save(file, table)
    local f = io.open(file, "w")
    f:write(serialization.serialize(table))
    f:close()
end

return data
