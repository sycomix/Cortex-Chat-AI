--[[
    This file provides the core functionality for the cortex ai. It handles
    communication between the neural network and incoming requests, and processes
    the output to ensure the response(s) conform to the expected personality.
]]

local M = {}

local CircularBuffer = require("circularbuff")

local ChatHistory = CircularBuffer.new(10)
local PlayerNameIndex = {}
local PlayerIDIndex = {}

local function FileExists(file)
    local f = io.open(file, "rb")
    if f then
        f:close()
    end
    return f ~= nil
end

local function ParseMessage(msg)
    local name = string.match(msg, "%[(.*)%]: ")
    local message = string.match(msg, ": (.*)")

    return name, message
end

local function LoadPlayerIndices(path)
    local pnameindex = {}
    local pidindex = {}
    local numloaded = 0

    if not FileExists(path) then
        return pnameindex, pidindex
    end

    for line in io.lines(path) do
        local id = string.match(line, "(%d+) : ")
        local name = string.match(line, " : (.*)")

        pnameindex[tonumber(id)] = name
        pidindex[name] = tonumber(id)

        numloaded = numloaded + 1
    end

    print("Loaded " .. tostring(numloaded) .. " player indices")

    return pnameindex, pidindex
end

local function GetPlayerName(id)
    if PlayerNameIndex[id] == nil then
        return PlayerIDIndex[200]
    else
        return PlayerNameIndex[id]
    end
end

local function GetPlayerID(name)
    if PlayerIDIndex[name] == nil then
        return 200
    else
        return PlayerIDIndex[name]
    end
end

local function implode(delimiter, list)
    local len = #list
    if len == 0 then
        return ""
    end
    local string = list[1]
    for i = 2, len do
        string = string .. delimiter .. list[i]
    end
    return string
end

local function explode(delimiter, text)
    local list = {}
    local pos = 1
    if string.find("", delimiter, 1) then
        error("delimiter matches empty string!")
    end
    while 1 do
        local first, last = string.find(text, delimiter, pos)
        if first then
            table.insert(list, string.sub(text, pos, first - 1))
            pos = last + 1
        else
            table.insert(list, string.sub(text, pos))
            break
        end
    end
    return list
end

local function TrimOutput(output, inlength)
    local lines = explode('\n', output)

    for i = 0, inlength - 1, 1 do
        table.remove(lines, 1)
    end

    return implode('\n', lines)
end

local function Init(model, usegpu)
    PlayerNameIndex, PlayerIDIndex = LoadPlayerIndices("players.txt")
end

local function AddMessage(name, message)
    ChatHistory:push("[" .. GetPlayerID(name) .. "]: " .. message)
end

local function GetResponse(ply, msg, config)
    AddMessage(ply, msg)

    local start_text = ''

    for i = #ChatHistory, 1, -1 do
        start_text = start_text .. ChatHistory[i] .. "\n"
    end

    start_text = start_text .. "[" .. GetPlayerID(config.personality) .. "]: "

    local cmdline = 'th sample.lua -verbose 0 -length ' .. config.length .. ' -temperature ' .. config.entropy .. ' -checkpoint ' .. config.model
    if not config.accelerate then
        cmdline = cmdline .. ' -gpu -1'
    end
    cmdline = cmdline .. ' -start_text "' .. start_text .. '"'

    print(cmdline)

    local f = assert(io.popen(cmdline))
    local output = f:read('*all')
    f:close()

    local trimmed = explode('\n', TrimOutput(output, #ChatHistory))

    local final = ''
    local rid = tonumber(GetPlayerID(config.personality))
    local added = 0

    while added < config.quantity do
        local id = tonumber(string.match(trimmed[added + 1], '%[(.*)%]: '))
        local m = string.match(trimmed[added + 1], ": (.*)")

        if id == rid then
            final = final .. m .. '\n'
            added = added + 1
        else
            break
        end
    end

    return final
end

M.AddMessage = AddMessage
M.GetResponse = GetResponse
M.Init = Init

return M
