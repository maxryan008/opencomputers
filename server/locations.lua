local fs = require("filesystem")
local serialization = require("serialization")
local ui = require("server.ui")

local LOCATION_DB = "/data/locations.db"

local M = {}

local function load()
    if not fs.exists(LOCATION_DB) then return {} end
    local file = io.open(LOCATION_DB, "r")
    local data = serialization.unserialize(file:read("*a"))
    file:close()
    return data or {}
end

local function save(locations)
    local file = io.open(LOCATION_DB, "w")
    file:write(serialization.serialize(locations))
    file:close()
end

function M.getAll()
    return load()
end

function M.get(name)
    return load()[name]
end

function M.exists(name)
    return load()[name] ~= nil
end

function M.add(name, slot, clientId)
    local locations = load()
    if locations[name] then return false end
    locations[name] = {
        slot = slot,
        client = clientId
    }
    save(locations)
    return true
end

function M.remove(name)
    local locations = load()
    locations[name] = nil
    save(locations)
end

function M.getFreeSlot()
    local used = {}
    for _, loc in pairs(load()) do
        used[loc.slot] = true
    end
    for i = 1, 54 do
        if not used[i] then return i end
    end
    return nil
end

function M.findBySlot(slot)
    for name, data in pairs(load()) do
        if data.slot == slot then
            return name
        end
    end
    return nil
end

function M.getAllowedForUser(user)
    local all = load()
    local allowed = require("server.users").getAllowedLocations(user)
    local result = {}
    for _, locName in ipairs(allowed) do
        if all[locName] then
            table.insert(result, locName)
        end
    end
    return result
end

function M.menu()
    while true do
        local locs = M.getAll()
        local names = {}
        for name in pairs(locs) do table.insert(names, name) end
        table.sort(names)
        table.insert(names, "[Add Location]")
        table.insert(names, "[Back]")

        local choice = ui.menu("Manage Locations", names)
        if not choice or names[choice] == "[Back]" then return end

        if names[choice] == "[Add Location]" then
            local name = ui.prompt("Location name")
            local clientId = ui.prompt("Client ID (e.g., modem address)")
            local slot = tonumber(ui.prompt("Target slot [1-54]")) or M.getFreeSlot()
            if not slot or slot < 1 or slot > 54 then
                ui.pause("Invalid or no slot available.")
            elseif M.exists(name) then
                ui.pause("Location already exists.")
            else
                M.add(name, slot, clientId)
                ui.pause("Location added: " .. name)
            end
        else
            local name = names[choice]
            local editing = true
            while editing do
                local loc = M.get(name)
                local submenu = {
                    "Edit Slot [" .. loc.slot .. "]",
                    "Edit Client ID [" .. loc.client .. "]",
                    "Delete Location",
                    "[Back]"
                }

                local action = ui.menu("Edit Location: " .. name, submenu)
                if action == 1 then
                    local newSlot = tonumber(ui.prompt("New slot [1-54]"))
                    if newSlot and newSlot >= 1 and newSlot <= 54 then
                        loc.slot = newSlot
                        M.remove(name)
                        M.add(name, newSlot, loc.client)
                    else
                        ui.pause("Invalid slot.")
                    end
                elseif action == 2 then
                    local newClient = ui.prompt("New client ID")
                    loc.client = newClient
                    M.remove(name)
                    M.add(name, loc.slot, newClient)
                elseif action == 3 then
                    M.remove(name)
                    ui.pause("Location deleted.")
                    editing = false
                else
                    editing = false
                end
            end
        end
    end
end

function M.getSlot(name)
    local loc = M.get(name)
    return loc and loc.slot or nil
end

function M.getClientId(name)
    local loc = M.get(name)
    return loc and loc.client or nil
end

return M