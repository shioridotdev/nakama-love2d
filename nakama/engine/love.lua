local log = require "nakama.util.log"
local b64 = require "nakama.util.b64"
local uri = require "nakama.util.uri"
local json = require "nakama.util.json"
local uuid = require "nakama.util.uuid"
local http = require "socket.http"

local b64_encode = b64.encode
local b64_decode = b64.decode
local uri_encode_component = uri.encode_component
local uri_decode_component = uri.decode_component
local uri_encode = uri.encode
local uri_decode = uri.decode

uuid.seed()

local M = {}

local function get_mac_address()
	return "00:00:00:00:00:00" -- for test purpose
	--local ifaddrs = sys.get_ifaddrs()
	--for _,interface in ipairs(ifaddrs) do
	--	if interface.mac then
	--		return interface.mac
	--	end
	--end
	--return nil
end

function M.uuid()
	local mac = get_mac_address()
	if not mac then
		print("Unable to get hardware mac address for UUID")
	end
	return uuid(mac)
end


function M.http(config, url_path, query_params, method, post_data, callback)
	local query_string = ""
	if next(query_params) then
		for query_key,query_value in pairs(query_params) do
			if type(query_value) == "table" then
				for _,v in ipairs(query_value) do
					query_string = ("%s%s%s=%s"):format(query_string, (#query_string == 0 and "?" or "&"), query_key, uri_encode_component(tostring(v)))
				end
			else
				query_string = ("%s%s%s=%s"):format(query_string, (#query_string == 0 and "?" or "&"), query_key, uri_encode_component(tostring(query_value)))
			end
		end
	end
	local url = ("%s%s%s"):format(config.http_uri, url_path, query_string)

	local headers = {}
	headers["Accept"] = "application/json"
	headers["Content-Type"] = "application/json"
	if config.bearer_token then
		headers["Authorization"] = ("Bearer %s"):format(config.bearer_token)
	elseif config.username then
		local credentials = b64_encode(config.username .. ":" .. config.password)
		headers["Authorization"] = ("Basic %s"):format(credentials)
	end

	local options = {
		timeout = config.timeout
	}

	print("HTTP", method, url)
	print("DATA", post_data)
	http.request(url, method, function(self, id, result)
		print(result.response)
		local ok, decoded = pcall(json.decode, result.response)
		if not ok then
			result.response = { error = true, message = "Unable to decode response" }
		elseif result.status < 200 or result.status > 299 then
			result.response = { error = decoded.error or true, message = decoded.message, code = decoded.code }
		else
			result.response = decoded
		end
		callback(result.response)
	end, headers, post_data, options)
end


function M.socket_create(config, on_message)
	assert(config, "You must provide a config")
	assert(on_message, "You must provide a message handler")

	local socket = {}
	socket.config = config
	socket.scheme = config.use_ssl and "wss" or "ws"

	socket.cid = 0
	socket.requests = {}
	socket.on_message = on_message

	return socket
end

local function on_message(socket, message)
	message = json.decode(message)
	if not message.cid then
		socket.on_message(socket, message)
		return
	end

	local callback = socket.requests[message.cid]
	if not callback then
		print("Unable to find callback for cid", message.cid)
		return
	end
	socket.requests[message.cid] = nil
	callback(message)
end

function M.socket_connect(socket, callback)
	assert(socket)
	assert(callback)

	local url = ("%s://%s:%d/ws?token=%s"):format(socket.scheme, socket.config.host, socket.config.port, uri.encode_component(socket.config.bearer_token))
	--const url = `${scheme}${this.host}:${this.port}/ws?lang=en&status=${encodeURIComponent(createStatus.toString())}&token=${encodeURIComponent(session.token)}`;

	print(url)

	local params = {
		protocol = nil,
		headers = nil,
		timeout = (socket.config.timeout or 0) * 1000,
	}
	socket.connection = websocket.connect(url, params, function(self, conn, data)
		if data.event == websocket.EVENT_CONNECTED then
			print("EVENT_CONNECTED")
			callback(true)
		elseif data.event == websocket.EVENT_DISCONNECTED then
			print("EVENT_DISCONNECTED: ", data.message)
			if socket.on_disconnect then socket.on_disconnect() end
		elseif data.event == websocket.EVENT_ERROR then
			print("EVENT_ERROR: ", data.message or data.error)
			callback(false, data.message or data.error)
		elseif data.event == websocket.EVENT_MESSAGE then
			print("EVENT_MESSAGE: ", data.message)
			on_message(socket, data.message)
		end
	end)
end

function M.socket_send(socket, message, callback)
	assert(socket and socket.connection, "You must provide a socket")
	assert(message, "You must provide a message to send")
	socket.cid = socket.cid + 1
	message.cid = tostring(socket.cid)
	socket.requests[message.cid] = callback

	local data = json.encode(message)
	-- Fix encoding of match_create and status_update messages to send {} instead of []
	if message.match_create ~= nil or message.status_update ~= nil then
		data = string.gsub(data, "%[%]", "{}")
	end

	local options = {
		type = websocket.DATA_TYPE_TEXT
	}
	websocket.send(socket.connection, data, options)
end

return M
