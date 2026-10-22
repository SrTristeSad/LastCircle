-- Server-authoritative Survev result projection and LÖVE rendering.
local Results={}
function Results.project(state)
    local msg=state and state.gameOver
    if not msg then return nil end
    local finished=msg.gameOver==true
    local rank=tonumber(msg.teamRank)
    if not rank or rank<=0 then rank=nil end
    local won=finished and msg.teamId~=nil and msg.winningTeamId~=nil
        and msg.teamId==msg.winningTeamId or false
    local stats={}
    for _,s in ipairs(type(msg.playerStats)=="table" and msg.playerStats or {}) do
        stats[#stats+1]={
            playerId=s.playerId, timeAlive=s.timeAlive,
            kills=s.kills,dead=s.dead,
            damageDealt=s.damageDealt,damageTaken=s.damageTaken,
        }
    end
    return {finished=finished,rank=rank,won=won,stats=stats}
end
local function value(n)
    return type(n)=="number" and tostring(n) or "—"
end
function Results.draw(state,width,height)
    local result=Results.project(state)
    if not result or not love or not love.graphics then return false end
    local g=love.graphics
    local w=math.min(640,width-24)
    local h=math.min(252+#result.stats*27,height-24)
    local x,y=(width-w)/2,(height-h)/2
    g.setColor(.018,.038,.04,.94)
    g.rectangle("fill",x,y,w,h,12,12)
    g.setColor(.68,.84,.72)
    g.rectangle("line",x,y,w,h,12,12)
    g.setColor(1,1,1)
    local heading=result.finished and (result.won and "VITORIA" or "PARTIDA ENCERRADA")
        or "RESULTADO RECEBIDO"
    g.printf(heading,x+12,y+18,w-24,"center")
    g.setColor(.98,.84,.46)
    g.printf(result.rank and ("POSICAO DA EQUIPE: #"..result.rank)
        or "Posicao nao informada",x+12,y+51,w-24,"center")
    g.setColor(.84,.92,.85)
    g.printf("ID   ABATES   DANO CAUSADO   DANO SOFRIDO   TEMPO (s)",
        x+10,y+91,w-20,"center")
    local maxRows=math.max(0,math.floor((h-159)/27))
    for i=1,math.min(#result.stats,maxRows) do
        local s=result.stats[i]
        local line=string.format("%s       %s             %s                 %s                 %s",
            value(s.playerId),value(s.kills),value(s.damageDealt),
            value(s.damageTaken),value(s.timeAlive))
        g.setColor(i%2==0 and .72 or .96,.91,.84)
        g.printf(line,x+10,y+98+i*27,w-20,"center")
    end
    g.setColor(.72,.84,.77)
    g.printf("Somente dados recebidos em GameOverMsg.",x+10,y+h-48,w-20,"center")
    g.printf("ESC: desconectar",x+10,y+h-27,w-20,"center")
    g.setColor(1,1,1,1)
    return true
end
return Results
