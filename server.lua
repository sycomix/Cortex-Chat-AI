--[[
    Cortex server written by Bradly Tillmann.

    Accepts post requests containing information regarding a request, and uses
    a neural network to generate a response. Due to the way the data is encoded,
    the network is capable of immitating any personality present in the training 
    data so long as there are sufficient occurences for the network to learn it.

    The network will limit it's concurrent responses to those of the same personality.
    The cortex server maintains a breif chat history of the requests made to the server
    in order to provide context to the neural network. This greatly improves its ability
    to respond with relevant and meaningful messages.
]]

local cortex = require('cortex')

local server = require("http.server")
local headers = require("http.headers")
local json = require("json")
local argparse = require("argparse")

local parser = argparse("cortexserver", "The cortex chat ai server.")
parser:option("-p --port", "Server port.", 8180):args(1)
parser:argument("model", "AI Model.")
parser:option("-e --entropy", "AI model entropy.", 0.4):args(1)
parser:flag("-a --accelerate", "Use GPU acceleration.")
parser:option("-l --length", "RNN Sequence length.", 1000):args(1)
parser:flag("-v --verbose", "Verbose output.")

local args = parser:parse()

local CortexConfig = {}

CortexConfig.model = args.model
CortexConfig.port = args.port
CortexConfig.entropy = args.entropy
CortexConfig.accelerate = args.accelerate
CortexConfig.length = args.length
CortexConfig.verbose = args.verbose

print('Starting with config:')
print(CortexConfig)

CortexConfig.personality = "Kendall Schmidt"
CortexConfig.quantity = 2

cortex.Init(CortexConfig.model, CortexConfig.accelerate)


local s = server.listen {
    host = '0.0.0.0',
    port = CortexConfig.port,
    onstream = function(sv, st)
        local rqh = st:get_headers()
        local rqm = rqh:get(':method')
        local path = rqh:get(':path') or '/'
        local rsh = headers.new()

        if path == '/cortex/respond' then
            local bdy = st:get_body_as_string()
            local body = json.parse(bdy)
            print(body)

            local ply_name = body.nn_name
            local ply_msg = body.nn_message
            
            CortexConfig.quantity = body.nn_max_rows

            if body.nn_personality ~= nil then CortexConfig.personality = body.nn_personality end

            if CortexConfig.quantity == 0 then
                cortex.AddMessage(ply_name, ply_msg)
                rsh:append(':status', '200')
                rsh:append('content-type', 'text/plain')
                st:write_headers(rsh, rqm == 'HEAD')
                st:write_chunk(' ', true)
            else
                local gen = cortex.GetResponse(ply_name, ply_msg, CortexConfig)
                rsh:append(':status', '200')
                rsh:append('content-type', 'text/plain')
                st:write_headers(rsh, rqm == 'HEAD')
                st:write_chunk(gen, true)
            end
        else
            rsh:append(':status', '404')
            rsh:append('content-type', 'text/plain')
            st:write_chunk('error', true)
        end
    end,
    onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end
}

print("Starting on port " .. CortexConfig.port)
s:listen()
s:loop()