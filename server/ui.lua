local term = require("term")
local event = require("event")

local M = {}

--- Clears screen and prints a centered header.
function M.header(title)
    term.clear()
    local w, _ = term.getViewport()
    local pad = math.floor((w - #title) / 2)
    print(string.rep(" ", pad) .. title)
    print(string.rep("-", w))
end

--- Displays a vertical menu and returns selected index.
--- @param options table<string> list of options
--- @param title string menu title
--- @return integer|nil selected index or nil if canceled
function M.menu(title, options)
    local selected = 1

    while true do
        M.header(title)
        for i, opt in ipairs(options) do
            if i == selected then
                print("-> " .. opt)
            else
                print("   " .. opt)
            end
        end
        print("\nUse ↑/↓ and ENTER. Q to cancel.")

        local code = M.waitForKeyPress()

        if code == 200 then -- up
            selected = (selected - 2) % #options + 1
        elseif code == 208 then -- down
            selected = selected % #options + 1
        elseif code == 28 then -- enter
            return selected
        elseif code == 16 then -- Q
            return nil
        end
    end
end

--- Reads /auth.key from a floppy and returns key + username.
--- @param fs table filesystem proxy
--- @return string key, string username
function M.readKey(fs)
    if not fs.exists("/auth.key") then
        return nil, nil
    end

    local handle, err = fs.open("/auth.key", "r")
    if not handle then
        return nil, nil
    end

    local data = fs.read(handle, math.huge)
    fs.close(handle)

    if not data then
        return nil, nil
    end

    local key, username = data:match("^(KEY%-%x+%-%w+)$")
    if not key then
        return nil, nil
    end

    -- Extract username from key format: KEY-XXXX-username
    username = key:match("KEY%-%x+%-(.+)")
    return key, username
end

--- Prompts the user to enter a line of text.
--- @param prompt string
--- @return string
function M.prompt(prompt)
    io.write(prompt .. ": ")
    return io.read()
end

--- Displays a list of values and allows selecting one to remove.
--- Returns the selected value or nil.
function M.selectAndRemove(title, values)
    local list = {}
    for i, v in ipairs(values) do
        list[i] = v
    end
    table.insert(list, "[Cancel]")

    local selected = M.menu(title, list)
    if selected == nil or selected > #values then
        return nil
    end

    return values[selected]
end

--- Allows selecting an item from a list of strings.
function M.select(title, values)
    local list = {}
    for i, v in ipairs(values) do
        list[i] = v
    end
    table.insert(list, "[Cancel]")

    local selected = M.menu(title, list)
    if selected == nil or selected > #values then
        return nil
    end

    return values[selected]
end

--- Displays a message and waits for keypress.
function M.pause(message)
    print(message or "\nPress any key to continue...")
    local code = M.waitForKeyPress()
end

--- Displays a toggleable true/false menu for properties.
--- @param props table<string, boolean>
--- @return table<string, boolean>|nil
function M.editProperties(props)
    local keys = {}
    for k in pairs(props) do
        table.insert(keys, k)
    end
    table.sort(keys)
    local selected = 1

    while true do
        M.header("Edit Properties")
        for i, key in ipairs(keys) do
            local val = props[key] and "true" or "false"
            local line = string.format("%s: %s", key, val)
            if i == selected then
                print("-> " .. line)
            else
                print("   " .. line)
            end
        end
        print("\nENTER = toggle | Q = cancel | S = save")

        local code = M.waitForKeyPress()
        if code == 200 then
            selected = (selected - 2) % #keys + 1
        elseif code == 208 then
            selected = selected % #keys + 1
        elseif code == 28 then
            local k = keys[selected]
            props[k] = not props[k]
        elseif code == 31 then -- S key
            return props
        elseif code == 16 then -- Q
            return nil
        end
    end
end

function M.waitForKeyPress()
    local code
    while true do
        local name, _, _, keyCode = coroutine.yield()
        if name == "key_down" then
            code = keyCode
        elseif name == "key_up" and keyCode == code then
            return code
        end
    end
end

return M