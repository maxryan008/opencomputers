local component = require("component")
local event = require("event")
local serialization = require("serialization")
local sides = require("sides")
local term = require("term")
local os = require("os")

local modem = component.modem
local transposer = component.transposer
local redstone = component.redstone

-- CONFIG --
local serverPort = 1234
local clientId = "client1"
local teleposerSide = sides.top
local sharedChestSide = sides.bottom
local redstoneSide = sides.north
--------------

modem.open(serverPort)

-- Move item between inventories
local function moveFocusToTeleposer(slot)
    return transposer.transferItem(sharedChestSide, teleposerSide, 1, slot, 1) > 0
end

local function moveFocusBack(fromSlot)
    for i = 1, transposer.getInventorySize(sharedChestSide) do
        local stack = transposer.getStackInSlot(sharedChestSide, i)
        if not stack then
            local moved = transposer.transferItem(teleposerSide, sharedChestSide, 1, 1, i)
            return moved > 0 and i or nil
        end
    end
    return nil
end

local function pulseRedstone()
    redstone.setOutput(redstoneSide, 15)
    os.sleep(0.1)
    redstone.setOutput(redstoneSide, 0)
end

-- Waits for modem response
local serverAddress = nil
local function waitForResponse(expected)
    while true do
        local _, _, from, _, _, cmd, a, b = event.pull("modem_message")
        if cmd == expected then
            serverAddress = from
            return cmd, a
        end
        if cmd == "denied" or cmd == "busy" or cmd == "failed" then
            print("Error: " .. (b or "Unknown error"))
            return nil
        end
    end
end

-- Wait for floppy insert and read key/username
local function waitForFloppy()
    term.clear()
    print("Insert floppy with /auth.key and label as username...")
    while true do
        local _, addr, ctype = event.pull("component_added")
        if ctype == "filesystem" then
            local proxy = component.proxy(addr)
            if proxy.exists("/auth.key") then
                local file = proxy.open("/auth.key", "r")
                local key = proxy.read(file, math.huge)
                proxy.close(file)
                local username = proxy.getLabel()
                return username, key
            end
        end
    end
end

-- Main logic per teleport session
local function mainLoop()
    term.clear()
    print("Teleport Client v1.0")

    local username, key = waitForFloppy()
    if not username or not key then
        print("Floppy missing label or key file.")
        return
    end

    print("Authenticating as " .. username .. "...")
    modem.broadcast(serverPort, "auth", username, key)
    local _, raw = waitForResponse("allowed")
    if not raw then return end

    local allowed = serialization.unserialize(raw)
    if not allowed or type(allowed) ~= "table" then
        print("Failed to get allowed locations from server.")
        return
    end

    -- Ask user to remove floppy
    print("PLEASE REMOVE FLOPPY DISK BEFORE CONTINUING!")
    os.sleep(1)
    io.write("Press ENTER when ready...")
    io.read()

    -- Select location
    term.clear()
    print("Select teleport location:")
    for i, loc in ipairs(allowed) do
        print(string.format("[%d] %s", i, loc))
    end
    io.write("Enter number: ")
    local index = tonumber(io.read())
    local destination = allowed[index]
    if not destination then
        print("Invalid choice.")
        return
    end

    print("Requesting teleport to " .. destination)
    modem.send(serverAddress, serverPort, "teleport", username, destination)
    local _, slot = waitForResponse("focus_ready")
    if not slot then return end

    print("Focus granted in slot " .. slot .. ". Moving to Teleposer...")
    if not moveFocusToTeleposer(slot) then
        print("Failed to move focus to Teleposer!")
        return
    end

    os.sleep(0.2)
    pulseRedstone()
    os.sleep(0.5)

    print("Returning focus to chest...")
    local returnSlot = moveFocusBack(slot)
    if not returnSlot then
        print("Failed to return focus!")
        return
    end

    modem.send(serverAddress, serverPort, "return", username, tostring(returnSlot))
    print("Teleportation complete.")
    os.sleep(2)
end

-- Loop forever
while true do
    mainLoop()
    os.sleep(1)
end