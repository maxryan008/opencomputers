local component = require("component")
local event = require("event")
local math = require("math")

-- Wait for a disk to be inserted
print("Insert a blank disk...")

local fsProxy = nil
while not fsProxy do
    local _, addr, ctype = event.pull("component_added")
    if ctype == "filesystem" then
        fsProxy = component.proxy(addr)
    end
end

-- Ask for username
io.write("Enter username: ")
local username = io.read()

-- Generate random key
local function generateKey()
    local key = ""
    for _ = 1, 16 do
        key = key .. string.format("%02X", math.random(0, 255))
    end
    return key
end

math.randomseed(os.time())
local randomPart = generateKey()
local fullKey = string.format("KEY-%s-%s", randomPart, username)

-- Write the key to /auth.key on the disk using proxy methods
local file, reason = fsProxy.open("/auth.key", "w")
if not file then
    print("Failed to open file for writing:", reason)
    return
end

fsProxy.write(file, fullKey)
fsProxy.setLabel(username)
fsProxy.close(file)

print("Key written to disk:")
print(fullKey)