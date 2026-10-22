-- Survev GameOverMsg presentation. Display only server-confirmed values.
-- No invented winner, placement or combat statistics.
local Results={}
function Results.project(state)
    local msg=state and state.gameOver
    if not msg then return nil end
    local rank=tonumber(msg.teamRank)
    if not rank or rank<=0 then rank=nil end
    local won=msg.gameOver and msg.teamId~=nil
        and msg.winningTeamId~=nil and msg.teamId==msg.winningTeamId
    return {
        finished=msg.gameOver==true,
        rank=rank,
        won=won,
        stats=type(msg.playerStats)=="table" and msg.playerStats or {},
    }
end
function Results.draw(state,width,height)
    local result=Results.project(state)
    if not result or not love or not love.graphics then return false end
    local g=love.graphics
    local w=math.min(520,width-24)
    local h=math.min(220,height-24)
    local x,y=(width-w)/2,(height-h)/2
    g.setColor(0,0,0,.82)
    g.rectangle("fill",x,y,w,h,12,12)
    g.setColor(.71,.85,.75,1)
    g.rectangle("line",x,y,w,h,12,12)
    g.setColor(1,1,1,1)
    local title=result.finished and (result.won and "VITORIA" or "PARTIDA ENCERRADA")
        or "RESULTADO DA EQUIPE"
    g.printf(title,x+12,y+25,w-24,"center")
    g.setColor(.96,.85,.48,1)
    g.printf(result.rank and ("POSICAO DA EQUIPE: #"..result.rank)
        or "Posicao aguardando confirmacao",x+12,y+76,w-24,"center")
    g.setColor(.75,.85,.79,1)
    g.printf("Dados recebidos do servidor (GameOverMsg).",x+12,y+123,w-24,"center")
    g.printf("ESC para desconectar",x+12,y+160,w-24,"center")
    g.setColor(1,1,1,1)
    return true
end
return Results
