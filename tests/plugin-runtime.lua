-- Exercise panel callbacks against the installed v5 API contract. In
-- particular, there is no appIconPath and runAsync accepts only strings.
local plugin = assert(arg[1])
local runtimeDir = "/tmp/bb auth's-$HOME;test"
local pluginDir = "/tmp/plugin's-$(echo test)"

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function exercise(filename, action, responseFile, legacyIcons)
    local state = {
        active = true,
        session_id = "test-session",
        requestor_icon = "application-icon",
    }
    local watchers, commands, messages = {}, {}, {}
    local renders = 0
    local env = setmetatable({}, { __index = _G })
    env.noctalia = {
        state = {
            get = function(key) return state[key] end,
            set = function(key, value) state[key] = value end,
            watch = function(key, callback) watchers[key] = callback end,
        },
        getenv = function(name)
            assert(name == "XDG_RUNTIME_DIR")
            return runtimeDir
        end,
        pluginDir = function() return pluginDir end,
        fileExists = function() return true end,
        writeFile = function(path, payload)
            assert(path == runtimeDir .. "/" .. responseFile)
            assert(type(payload) == "string")
            return true
        end,
        removeFile = function() end,
        json = {
            encode = function(message)
                table.insert(messages, message)
                return "{}"
            end,
        },
        runAsync = function(command)
            assert(type(command) == "string", "runAsync requires a command string")
            assert(command:find("/bin/python3' ", 1, true))
            local tail = quote(pluginDir .. "/send.py") .. " "
                .. quote(runtimeDir .. "/" .. responseFile)
            assert(command:sub(-#tail) == tail, "arguments must be POSIX shell quoted")
            table.insert(commands, command)
            return true
        end,
        notifyError = function(_, message) error(message) end,
    }
    if legacyIcons then
        env.noctalia.appIconPath = function() return "/tmp/icon.png" end
    end
    env.ui = {}
    for _, name in ipairs({ "column", "row", "label", "image", "input", "button", "glyph" }) do
        env.ui[name] = function(props, children) return { props = props, children = children } end
    end
    env.panel = {
        render = function(tree)
            assert(type(tree) == "table")
            renders = renders + 1
        end,
        close = function() env.onClose() end,
    }
    assert(loadfile(plugin .. "/" .. filename, "t", env))()
    env.onOpen()
    assert(renders == 1)
    for _, callback in pairs(watchers) do callback() end
    if action == "submit" then
        env.onPasswordChanged("dummy-test-value")
        env.onSubmit()
    elseif action == "cancel" then
        env.onCancel()
    else
        env.onClose()
    end
    assert(#commands == 1, "response must be sent exactly once")
    assert(#messages == 1)
    assert(messages[1].id == "test-session")
    if action == "submit" then
        assert(messages[1].type == "session.respond")
        assert(messages[1].response == "dummy-test-value")
    else
        assert(messages[1].type == "session.cancel")
        assert(state.cancel_session_id == "test-session")
    end
end

exercise("panel.luau", "cancel", "noctalia-bb-auth-cancel.json")
exercise("panel.luau", "close", "noctalia-bb-auth-cancel.json")
exercise("panel.luau", "submit", "noctalia-bb-auth-response.json")
exercise("panel.luau", "cancel", "noctalia-bb-auth-cancel.json", true)
exercise("blocked.luau", "close", "noctalia-bb-auth-blocked-cancel.json")
local function exerciseService(legacyClock)
    local state, streamCallback = {}, nil
    local clock, notifications = 10, 0
    local env = setmetatable({}, { __index = _G })
    env.os = { clock = function() return clock end }
    env.noctalia = {
        state = {
            get = function(key) return state[key] end,
            set = function(key, value) state[key] = value end,
        },
        pluginDir = function() return plugin end,
        setUpdateInterval = function(ms) assert(ms == 100) end,
        runStream = function(command, callback)
            assert(type(command) == "string")
            streamCallback = callback
            return true
        end,
        json = { decode = function(message) return message end },
        togglePanel = function() end,
        notify = function() notifications = notifications + 1 end,
        notifyError = function(_, message) error(message) end,
    }
    if legacyClock then
        env.noctalia.nowMs = function() return clock * 1000 end
    end
    assert(loadfile(plugin .. "/service.luau", "t", env))()
    streamCallback({ type = "session.created", id = "test-session", source = "pinentry" })
    streamCallback({ type = "session.updated", id = "test-session", prompt = "PIN" })
    streamCallback({ type = "session.closed", id = "test-session", result = "success" })
    env.update()
    assert(state.active == true and notifications == 0)
    clock = clock + 2
    env.update()
    assert(state.active == false and notifications == 1)
    env.onExit()
end

exerciseService(false)
exerciseService(true)
print("Panel callbacks and service completion checks passed")
