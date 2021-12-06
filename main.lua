--NAKAMA IMPORT
local nakama = require "nakama.nakama"
local log = require "nakama.util.log"
local love2d = require "nakama.engine.love"

--CORE IMPORT
local importHandler = require 'core/handler/importHandler'
function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

 
local function device_login(client)
	local body = nakama.create_api_account_device(love2d.uuid())
	local result = nakama.authenticate_device(client, body, true)
    if result then
        if result.token then
            nakama.set_bearer_token(client, result.token)
            return true
        end
    end
	print("Unable to login")
	return false
end

--CORE FUNCTION
function love.load()
    --load nakama
	local config = {
        host = "localhost",
        port = 7350,
        use_ssl = false,
        username = "defaultkey",
        password = "",
        engine = love2d,
        timeout = 10,
	}
	local client = nakama.create_client(config)

    nakama.sync(function()
        device_login(client)
    end)
    --default font
    font = love.graphics.newFont('src/font.ttf', 32)

    --common sfx
    sfx_cmn_cancel = love.audio.newSource('src/sound/sfx/common/sfx_cancel.ogg', 'stream')
    sfx_cmn_confirm = love.audio.newSource('src/sound/sfx/common/sfx_confirm.ogg', 'stream')
    sfx_cmn_select = love.audio.newSource('src/sound/sfx/common/sfx_select.ogg', 'stream')
    sfx_cmn_start = love.audio.newSource('src/sound/sfx/common/sfx_start.ogg', 'stream')
end

function love.update()
    love.keyboard.keysPressed = {}
end

function love.draw()
    love.graphics.setFont(font)
    love.graphics.printf({{255,255,255}, 'CORE ENGINE IS WORKING'}, 100, 50, 200, "left")
end