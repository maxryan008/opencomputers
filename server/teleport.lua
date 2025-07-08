local component = require("component")
local transposer = component.transposer
local serialization = require("serialization")
local sides = require("sides")
local data = require("/server/data")

local teleport = {}

local locationFile = "/data/locations.db"
local storageChestSide = sides.north
local sharedChestSide = sides.south

local locations = data.load(locationFile, {})

function teleport.getAvailableLocationsFor(user)
    local result = {}
    local users = require("server.users")
    local allowed = users.getAllowedLocations(user)
    for _, loc in ipairs(allowed or {}) do
        if locations[loc] then
            table.insert(result, loc)
        end
    end
    return result
end


function teleport.sendFocus(locationName)
    local location = locations[locationName]
    if not location then return nil end
    local slot = location.slot
    -- check if that slot contains a focus
    local stack = transposer.getStackInSlot(storageChestSide, slot)
    if not stack then return nil end

    -- find empty slot on shared side
    for i = 1, transposer.getInventorySize(sharedChestSide) do
        if not transposer.getStackInSlot(sharedChestSide, i) then
            transposer.transferItem(storageChestSide, sharedChestSide, 1, slot, i)
            return i
        end
    end
    return nil
end

function teleport.reclaimFocus(fromSlot)
    -- find empty slot in storage
    for i = 1, transposer.getInventorySize(storageChestSide) do
        if not transposer.getStackInSlot(storageChestSide, i) then
            transposer.transferItem(sharedChestSide, storageChestSide, 1, fromSlot, i)
            return i
        end
    end
    return nil
end

return teleport