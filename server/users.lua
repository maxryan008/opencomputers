local fs = require("filesystem")
local serialization = require("serialization")
local event = require("event")
local component = require("component")
local ui = require("server.ui")

local USER_DB = "/data/keys.db"

local M = {}

local function load()
    if not fs.exists(USER_DB) then return {} end
    local file = io.open(USER_DB, "r")
    local data = serialization.unserialize(file:read("*a"))
    file:close()
    return data or {}
end

local function save(users)
    local file = io.open(USER_DB, "w")
    file:write(serialization.serialize(users))
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

function M.add(user, key, isAdmin)
    local users = load()
    if users[user] then return false end
    users[user] = {
        key = key,
        admin = isAdmin or false,
        allowed = {}
    }
    save(users)
    return true
end

function M.delete(name)
    local users = load()
    users[name] = nil
    save(users)
end

function M.setAdmin(name, isAdmin)
    local users = load()
    if users[name] then
        users[name].admin = isAdmin
        save(users)
    end
end

function M.toggleAdmin(name)
    local users = load()
    if users[name] then
        users[name].admin = not users[name].admin
        save(users)
    end
end

function M.setAllowedLocations(name, locations)
    local users = load()
    if users[name] then
        users[name].allowed = locations
        save(users)
    end
end

-- 🔧 FIXED: accept either user table or username
function M.getAllowedLocations(user)
    if type(user) == "table" then
        return user.allowed or {}
    elseif type(user) == "string" then
        local u = M.get(user)
        return u and u.allowed or {}
    else
        return {}
    end
end

-- 🔧 FIXED: same logic for admin check
function M.isAdmin(user)
    if type(user) == "table" then
        return user.admin or false
    elseif type(user) == "string" then
        local u = M.get(user)
        return u and u.admin or false
    else
        return false
    end
end

function M.menu()
    while true do
        local users = M.getAll()
        local usernames = {}
        for name in pairs(users) do table.insert(usernames, name) end
        table.sort(usernames)
        table.insert(usernames, "[Add User]")
        table.insert(usernames, "[Back]")

        local choice = ui.menu("User Management", usernames)
        if choice == nil or usernames[choice] == "[Back]" then return end

        if usernames[choice] == "[Add User]" then
            ui.header("Insert Floppy")
            print("Waiting for a floppy disk...")

            local fsProxy = nil
            while not fsProxy do
                local _, addr, ctype = event.pull("component_added")
                if ctype == "filesystem" then
                    local proxy = component.proxy(addr)
                    local label = proxy.getLabel()
                    if label and proxy.exists("/auth.key") then
                        fsProxy = proxy
                        break
                    end
                end
            end

            local key, username = ui.readKey(fsProxy)
            if not M.exists(username) then
                M.add(username, key, false)
                ui.pause("User added: " .. username)
            else
                ui.pause("User already exists.")
            end

        else
            local name = usernames[choice]
            local editing = true
            while editing do
                local u = M.get(name)
                local submenu = {
                    "Toggle Admin [" .. tostring(u.admin) .. "]",
                    "Edit Allowed Locations",
                    "Delete User",
                    "[Back]"
                }
                local action = ui.menu("Edit User: " .. name, submenu)

                if action == 1 then
                    M.toggleAdmin(name)
                elseif action == 2 then
                    local locs = require("server.locations").getAll()
                    local props = {}
                    for locName in pairs(locs) do
                        props[locName] = false
                    end
                    for _, loc in ipairs(u.allowed or {}) do
                        props[loc] = true
                    end
                    local edited = ui.editProperties(props)
                    if edited then
                        local newAllowed = {}
                        for loc, allowed in pairs(edited) do
                            if allowed then table.insert(newAllowed, loc) end
                        end
                        M.setAllowedLocations(name, newAllowed)
                    end
                elseif action == 3 then
                    M.delete(name)
                    ui.pause("User deleted.")
                    editing = false
                else
                    editing = false
                end
            end
        end
    end
end

return M