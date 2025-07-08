local component = require("component")
local event = require("event")
local serialization = require("serialization")
local data = require("server.data")
local teleport = require("server.teleport")
local utils = require("server.utils")
local usersLib = require("server.users")
local locationsLib = require("server.locations")
local ui = require("server.ui")
local term = require("term")
local modem = component.modem
modem.open(1234)

local fs = require("filesystem")
local keyFile = "/data/keys.db"
local sessionPath = "/data/sessions/"
if not fs.exists("/data") then fs.makeDirectory("/data") end
if not fs.exists(sessionPath) then fs.makeDirectory(sessionPath) end

-- Shared state
local quit = false

-- Clean expired sessions
local function cleanSessions()
    for file in fs.list(sessionPath) do
        local f = io.open(sessionPath .. file, "r")
        local content = serialization.unserialize(f:read("*a"))
        f:close()

        if os.time() - content.time > 60 then
            fs.remove(sessionPath .. file)
            utils.log("Session expired" .. (content.user and (" for " .. content.user) or ""))
        end
    end
end

-- Handle incoming client request
local function handleClient(from, user, key)
    local entry = usersLib.get(user)
    if not entry or entry.key ~= key then
        modem.send(from, 1234, "denied", "Invalid credentials")
        return
    end

    cleanSessions()
    if fs.exists(sessionPath .. user) then
        modem.send(from, 1234, "busy", "Session already active")
        return
    end

    local allowed = teleport.getAvailableLocationsFor(entry)
    local session = {
        user = user,
        client = from,
        time = os.time(),
        locked = false
    }

    local f = io.open(sessionPath .. user, "w")
    f:write(serialization.serialize(session))
    f:close()
    modem.send(from, 1234, "allowed", serialization.serialize(allowed))
    utils.log("Session started for " .. user)
end

-- Handle teleport request
local function handleTeleport(from, user, location)
    local sessionFile = sessionPath .. user
    if not fs.exists(sessionFile) then return end

    local f = io.open(sessionFile, "r")
    local session = serialization.unserialize(f:read("*a"))
    f:close()

    if session.client ~= from then return end

    -- try to send focus
    local slot = teleport.sendFocus(location)
    if not slot then
        modem.send(from, 1234, "failed", "Location unavailable")
        return
    end

    -- update session
    session.locked = true
    session.slot = slot
    session.time = os.time()
    f = io.open(sessionFile, "w")
    f:write(serialization.serialize(session))
    f:close()

    modem.send(from, 1234, "focus_ready", slot)
    utils.log("Focus sent for " .. user .. " to " .. location)
end

-- Handle focus return
local function handleReturn(from, user, fromSlot)
    local sessionFile = sessionPath .. user
    if not fs.exists(sessionFile) then return end

    local f = io.open(sessionFile, "r")
    local session = serialization.unserialize(f:read("*a"))
    f:close()

    if session.client ~= from then return end

    local target = teleport.reclaimFocus(fromSlot)
    if not target then
        modem.send(from, 1234, "error", "Failed to return focus")
        return
    end

    fs.remove(sessionFile)
    modem.send(from, 1234, "done")
    utils.log("Focus returned by " .. user .. " to slot " .. target)
end

-- Coroutine 1: modem handler
local function modemHandler()
    print("test")
    while not quit do
        local _, _, from, _, _, command, arg1, arg2 = coroutine.yield("modem_message")
        if command == "auth" then
            handleClient(from, arg1, arg2)
        elseif command == "teleport" then
            handleTeleport(from, arg1, arg2)
        elseif command == "return" then
            handleReturn(from, arg1, tonumber(arg2))
        end
    end
end

-- Coroutine 2: admin console
local function consoleHandler()
    local options = {
        "View Sessions",
        "Manage Users",
        "Manage Locations",
        "Shutdown Server"
    }
    local selected = 1

    while not quit do
        term.clear()
        print("== Teleposer Server ==")
        for i, opt in ipairs(options) do
            print((i == selected and "-> " or "   ") .. opt)
        end
        print("\nUse ↑/↓ and ENTER. Press Q to quit.")

        local code = ui.waitForKeyPress()

        if code == 200 then
            selected = (selected - 2) % #options + 1
        elseif code == 208 then
            selected = selected % #options + 1
        elseif code == 28 then
            if selected == 1 then
                term.clear()
                print("Active sessions:")
                for file in fs.list(sessionPath) do
                    print("- " .. file)
                end
                print("Press any key to return...")
                local code = ui.waitForKeyPress()

            elseif selected == 2 then
                usersLib.menu()

            elseif selected == 3 then
                locationsLib.menu()

            elseif selected == 4 then
                term.clear()
                print("Shutting down...")
                quit = true
                return
            end

        elseif code == 16 then
            term.clear()
            print("Shutting down from menu...")
            quit = true
            return
        end
    end
end

-- Event dispatcher to both coroutines
local function runCoroutines(...)
    local coroutines = {
        coroutine.create(modemHandler),
        coroutine.create(consoleHandler)
    }

    while not quit do
        local e = {event.pull()}
        for i, co in ipairs(coroutines) do
            if coroutine.status(co) ~= "dead" then
                local ok, err = coroutine.resume(co, table.unpack(e))
                if not ok then
                    print("[Error in coroutine]: " .. tostring(err))
                end
            end
        end
    end
end

runCoroutines()