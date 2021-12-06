function soundHandlerSfx(sfx)
    sfx:stop()
    sfx:play()
end

function soundHandlerMusicPlay(music)
    love.audio.play(music)
end

function soundHandlerMusicStop()
    love.audio.stop()
end