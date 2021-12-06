--INPUT CORE FUNCTION
function love.keypressed(key)
    switch(key, { 
    ['escape'] = function()
        love.event.quit()
	end
    })
    love.keyboard.keysPressed[key] = true
end

function love.keyboard.wasPressed(key)
    return love.keyboard.keysPressed[key]
end