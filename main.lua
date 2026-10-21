-- LastCircle / Survev Lua: real WebSocket connection + asset and state inspector.
-- The original renderer, map generator and full gameplay are NOT ported yet.
-- Press F6 for the optional network debug tool. No fictitious battle royale.
local Camera=require("src.survev.camera")
local Binds=require("src.survev.input_bindings")
local Config=require("src.survev.game_config")
local Input=require("src.survev.input_msg")
local Network=require("src.survev.network_client")
local LiveDebug=require("src.survev.live_debug")

local camera=Camera.new()
local screen="assets"
local tile,logo,selected,live
local index=1
local imageErrors={}
local sampleFiles={
    {"player/player-base-01.png","Player: player-base-01.svg"},
    {"player/player-hands-01.png","Player: player-hands-01.svg"},
    {"map/map-barrel-01.png","Mapa: map-barrel-01.svg"},
    {"map/map-airdrop-01.png","Mapa: map-airdrop-01.svg"},
    {"guns/gun-famas-01.png","Arma: gun-famas-01.svg"},
    {"loot/loot-medical-healthkit.png","Loot: loot-medical-healthkit.svg"},
    {"gui/crosshair.png","Interface: crosshair.svg"},
}
-- User supplies matchmaking-provided URL and token. The token never goes to disk.
local fields={
    {label="Servidor WebSocket (ws/wss)",value="",placeholder="ws://127.0.0.1:PORTA/jogo"},
    {label="Join token fornecido pelo matchmaking",value="",placeholder="Token de entrada",secret=true},
    {label="Nome do jogador",value="Jogador Lua",placeholder="Nome"},
    {label="CA confiavel para wss:// (LuaSec)",value="",placeholder="Caminho do arquivo de certificados",optional=true},
}
local focus=1
local client
local status=""
local actionQueue={}
local fireStart=false
local font
local function loadImage(path)
    if not love.filesystem.getInfo(path) then return nil end
    local ok,res=pcall(love.graphics.newImage,path)
    if ok then res:setFilter("linear","linear");return res end
    imageErrors[#imageErrors+1]=path..": "..tostring(res)
    return nil
end
local function selectImage()
    selected=loadImage("assets/survev/img/"..sampleFiles[index][1])
end
local function centered(image,x,y,maxSize)
    if not image then return end
    local iw,ih=image:getDimensions()
    local scale=math.min(maxSize/iw,maxSize/ih,3)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(image,x,y,0,scale,scale,iw/2,ih/2)
end
local function connected()
    return client and (client.state=="joined" or client.state=="connected"
        or client.state=="finished") and client.connection
        and client.connection.state=="open"
end
local function setConnection()
    if fields[1].value=="" then status="Informe o endereco WebSocket real.";return end
    if fields[2].value=="" then
        status="Informe um joinToken valido do servidor Survev.";return
    end
    local options={timeout=4}
    if fields[4].value~="" then options.caFile=fields[4].value end
    client=Network.new(options)
    local ok,err=client:connect(fields[1].value,{
        name=fields[3].value,joinToken=fields[2].value,
        useTouch=false,isMobile=false,
    })
    if not ok then status="Falha na conexao: "..tostring(err)
    else status="WebSocket conectado. Aguardando JoinedMsg..." end
end
local function addAction(id)
    actionQueue[#actionQueue+1]=id
end
function love.load()
    love.window.setTitle("LastCircle - Survev Lua | Arte e Rede (desenvolvimento)")
    font=love.graphics.newFont(16)
    love.graphics.setFont(font)
    tile=loadImage("assets/survev/img/intro/map_tile.png")
    logo=loadImage("assets/survev/img/survev_logo_full.png")
    selectImage()
    live=LiveDebug.new()
end
function love.resize(w,h)
    camera.m_screenWidth,camera.m_screenHeight=w,h
end
function love.textinput(s)
    if screen~="network" or connected() then return end
    local field=fields[focus]
    if #field.value<1500 and not s:find("[%c]") then
        field.value=field.value..s
    end
end
local function backspace(str)
    if str=="" then return str end
    local ok,utf8=pcall(require,"utf8")
    if ok then
        local pos=utf8.offset(str,-1)
        if pos then return str:sub(1,pos-1) end
    end
    return str:sub(1,-2)
end
function love.keypressed(key)
    if key=="f6" then
        screen=screen=="assets" and "network" or "assets"
        return
    end
    if key=="escape" then
        if client and client.connection and client.connection.state=="open" then
            client:close()
            status="Desconectado."
        elseif screen=="network" then
            screen="assets"
        else
            love.event.quit()
        end
        return
    end
    if screen=="assets" then
        if key=="right" or key=="d" then
            index=index%#sampleFiles+1;selectImage()
        elseif key=="left" or key=="a" then
            index=(index-2)%#sampleFiles+1;selectImage()
        end
        return
    end
    if not connected() then
        if key=="tab" then focus=focus%#fields+1
        elseif key=="return" or key=="kpenter" then setConnection()
        elseif key=="backspace" then fields[focus].value=backspace(fields[focus].value)
        elseif key=="v" and love.keyboard.isDown("lctrl","rctrl") then
            local pasted=love.system.getClipboardText() or ""
            pasted=pasted:gsub("[%c]","")
            fields[focus].value=(fields[focus].value..pasted):sub(1,1500)
        end
        return
    end
    -- Original Survev action IDs from shared/gameConfig.ts
    local keyActions={
        r=Binds.Input.Reload,f=Binds.Input.Interact,
        e=Binds.Input.StowWeapons,
        ["1"]=Binds.Input.EquipPrimary,["2"]=Binds.Input.EquipSecondary,
        ["3"]=Binds.Input.EquipMelee,["4"]=Binds.Input.EquipThrowable,
        ["7"]=Binds.Input.UseBandage,["8"]=Binds.Input.UseHealthKit,
        ["9"]=Binds.Input.UseSoda,["0"]=Binds.Input.UsePainkiller,
        q=Binds.Input.EquipLastWeap,t=Binds.Input.SwapWeapSlots,
        m=Binds.Input.ToggleMap,
    }
    if keyActions[key] then addAction(keyActions[key]) end
end
function love.mousepressed(x,y,button)
    if screen~="network" then return end
    if connected() then
        if button==1 then fireStart=true end
        return
    end
    local w=love.graphics.getWidth()
    local x0=w/2-300
    for i=1,#fields do
        local sy=164+(i-1)*74
        if x>=x0 and x<=x0+600 and y>=sy and y<=sy+39 then
            focus=i
            break
        end
    end
end
local atan2=math.atan2 or math.atan
function love.update(dt)
    if not client then return end
    client:poll()
    local world=client:getGameState()
    if world and world.map then live:update(world,dt) end
    if screen~="network" or not connected() or not client:getGameState()
        or not client:getGameState().joined then return end
    local state=client:getGameState()
    local player=state.objects[state.activeId]
    if not player or not player.pos then return end
    local msg=Input.new()
    msg.moveLeft=love.keyboard.isDown("a")
    msg.moveRight=love.keyboard.isDown("d")
    msg.moveUp=love.keyboard.isDown("w")
    msg.moveDown=love.keyboard.isDown("s")
    msg.shootStart=fireStart
    msg.shootHold=love.mouse.isDown(1)
    local mx,my=love.mouse.getPosition()
    local pos=live.camera:m_screenToPoint({x=mx,y=my})
    local dx,dy=pos.x-player.pos.x,pos.y-player.pos.y
    local dist=math.sqrt(dx*dx+dy*dy)
    if dist>0.00001 then
        msg.toMouseDir={x=dx/dist,y=dy/dist}
        msg.toMouseLen=math.min(64,dist)
    end
    for _,id in ipairs(actionQueue) do msg:addInput(id) end
    actionQueue={}
    fireStart=false
    local ok,err=pcall(function() client:sendInput(msg,dt) end)
    if not ok then status="Falha no envio: "..tostring(err) end
end
local function drawAssets(w,h)
    local g=love.graphics
    g.clear(.18,.37,.22)
    if tile then
        local tw,th=tile:getDimensions()
        g.setColor(1,1,1)
        for y=0,h,th do for x=0,w,tw do g.draw(tile,x,y) end end
    end
    g.setColor(.04,.10,.09,.88)
    g.rectangle("fill",math.max(0,w/2-345),22,math.min(690,w),h-44,8)
    if logo then centered(logo,w/2,125,330)
    else
        g.setColor(.96,.98,.94)
        g.printf("SURVEV - ARTE ORIGINAL NAO PREPARADA",0,96,w,"center")
    end
    g.setColor(1,1,1)
    g.printf("INSPECAO DE RECURSOS ORIGINAIS",0,195,w,"center")
    g.setColor(.84,.91,.82)
    g.printf("F6: conexao de rede | A/D ou setas: alternar arte | ESC: sair",0,233,w,"center")
    g.printf("Ainda nao e uma partida jogavel.",0,262,w,"center")
    if selected then centered(selected,w/2,h/2+20,math.min(250,h*.3)) end
    g.setColor(1,1,1)
    g.printf(sampleFiles[index][2].." ("..index.."/"..#sampleFiles..")",0,h-125,w,"center")
    g.setColor(.8,.87,.8)
    g.printf("Protocolo "..Config.protocolVersion..
        " | Interagir: "..Binds.default.Interact[2]:upper()..
        " | Guardar arma: "..Binds.default.StowWeapons[2]:upper(),0,h-76,w,"center")
    if #imageErrors>0 then
        g.setColor(1,.53,.42)
        g.printf("Falha ao carregar alguns recursos originais. Consulte console.",0,h-48,w,"center")
    end
end
local function drawNetwork(w,h)
    local g=love.graphics
    if client and client:getGameState() and client:getGameState().map then
        live:draw(client:getGameState(),w,h)
    else
        g.clear(.13,.17,.16)
    end
    g.setColor(.03,.07,.07,.92)
    g.rectangle("fill",w/2-355,40,710,80,8)
    g.setColor(.95,.96,.90)
    g.printf("SURVEV LUA - DIAGNOSTICO DE CONEXAO",0,57,w,"center")
    g.setColor(.78,.87,.78)
    g.printf("F6: Artes originais | ESC: desconectar/voltar",0,88,w,"center")

    if connected() then
        local state=client:getGameState()
        local statusText="Conexao: "..client.state..
            " | MapMsg: "..tostring(state and state.map and state.map.mapName or "aguardando")..
            " | Atualizacoes: "..tostring(state and state.updateCount or 0)
        g.setColor(.95,.97,.87)
        g.printf(statusText,0,128,w,"center")
        g.printf("WASD / mouse: envia InputMsg original; servidor e autoridade.",0,h-88,w,"center")
        return
    end
    local x=w/2-300
    for i,field in ipairs(fields) do
        local y=164+(i-1)*74
        g.setColor(.92,.96,.91)
        g.print(field.label,x,y-24)
        g.setColor(.09,.14,.14,.95)
        g.rectangle("fill",x,y,600,39,5)
        g.setColor(i==focus and {.96,.85,.43} or {.47,.62,.53})
        g.rectangle("line",x,y,600,39,5)
        local content=field.value
        if field.secret then content=string.rep("*",math.min(#content,64)) end
        if content=="" then g.setColor(.53,.62,.57);content=field.placeholder
        else g.setColor(.95,.96,.92) end
        g.setScissor(x+9,y,582,39)
        g.print(content,x+10,y+9)
        g.setScissor()
    end
    g.setColor(.91,.94,.82)
    g.printf("Clique no campo, digite e pressione ENTER para conectar.",0,485,w,"center")
    g.setColor(.78,.89,.78)
    g.printf("URLs/token reais vem do matchmaking. wss:// exige LuaSec e CA confiavel.",
        0,510,w,"center")
    if client then
        g.setColor(client.error and {.98,.42,.38} or {.72,.91,.71})
        g.printf("Estado: "..client.state..
            (client.error and (" | "..client.error) or ""),20,558,w-40,"center")
    elseif status~="" then
        g.setColor(.96,.59,.4);g.printf(status,20,558,w-40,"center")
    end
    g.setColor(.98,.54,.37)
    g.printf("A interface e de diagnostico. A renderizacao original ainda sera portada.",
        0,h-58,w,"center")
end
function love.draw()
    local g=love.graphics
    local w,h=g.getDimensions()
    camera.m_screenWidth,camera.m_screenHeight=w,h
    if screen=="assets" then drawAssets(w,h)
    else drawNetwork(w,h) end
end
