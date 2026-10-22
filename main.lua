-- LastCircle / Survev Lua: real WebSocket connection + asset and state inspector.
-- Original terrain, obstacles, interiors, wall-aware roof LOS and door
-- visual interpolation are partially ported. Full layer masks/player/HUD
-- gameplay is NOT complete. No invented mechanics.
-- LOCAL visual test starts immediately. F6 opens network mode, F7 assets.
-- Local input is a marked sandbox, never simulated server authority.
local Camera=require("src.survev.camera")
local Binds=require("src.survev.input_bindings")
local Config=require("src.survev.game_config")
local Input=require("src.survev.input_msg")
local LiveInput=require("src.survev.live_input")
local Network=require("src.survev.network_client")
local Match=require("src.survev.matchmaking")
local LiveDebug=require("src.survev.live_debug")
local OfflineDemo=require("src.survev.offline_demo")
local Minimap=require("src.survev.minimap")
local InteractionHint=require("src.survev.interaction_hint")
local InventoryPanel=require("src.survev.inventory_panel")
local Hud=require("src.survev.hud")
local ResultsOverlay=require("src.survev.results_overlay")
local PickupFeedback=require("src.survev.pickup_feedback")
local EquipmentTracker=require("src.survev.equipment_tracker")

local camera=Camera.new()
local screen=os.getenv("LASTCIRCLE_DEMO_SMOKE")=="1" and "demo" or "network"
local tile,logo,selected,live,demo,hud,minimap,inventoryPanel,pickupFeedback,equipmentTracker
local smokeFrames=0
local screenshotRequested=false
local equipmentScreenshotRequested=false
local mapScreenshotRequested=false
local inventoryScreenshotRequested=false
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
-- The original client starts by requesting /api/find_game_v2. Direct
-- URL+token is retained only as an advanced local-server test option.
local fields={
    {label="URL DA API SURVEV",value="",placeholder="http://127.0.0.1:8000"},
    {label="WebSocket direto (avancado)",value="",placeholder="ws://127.0.0.1:PORTA/jogo"},
    {label="Join token direto (avancado)",value="",placeholder="Token real do servidor",secret=true},
    {label="Nome do jogador",value="Jogador Lua",placeholder="Nome"},
    {label="CA confiavel para HTTPS/WSS (LuaSec)",value="",placeholder="Arquivo de certificados (opcional em HTTP local)"},
    {label="Regiao Survev",value="na",placeholder="ID original de regiao, ex.: na"},
}
local focus=1
local gameModeIdx=0
local showDebug=false
local client
local status=""
local pendingInput=LiveInput.new()
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
local function optionsForConnect()
    local options={timeout=5}
    if fields[5].value~="" then options.caFile=fields[5].value end
    return options
end
local function setConnection()
    if client and client.connection then client:close() end
    client=nil
    if fields[2].value=="" or fields[3].value=="" then
        status="Modo direto exige URL e token REAIS.";return
    end
    client=Network.new(optionsForConnect())
    local ok,err=client:connect(fields[2].value,{
        name=fields[4].value,joinToken=fields[3].value,
        useTouch=false,isMobile=false,
    })
    if not ok then status="Conexao direta: "..tostring(err)
    else status="WebSocket conectado. Aguardando JoinedMsg..." end
end
local function quickPlay()
    if client and client.connection then client:close() end
    client=nil
    if fields[1].value=="" then
        status="Informe a URL real da API Survev.";return
    end
    status="Consultando /api/find_game_v2..."
    local options=optionsForConnect()
    options.region=fields[6].value
    options.gameModeIdx=gameModeIdx
    options.zones={}
    local result,reason=Match.request(fields[1].value,options)
    if not result then
        if reason=="invalid_captcha" then
            status="Este servidor exige Turnstile; login/captcha ainda nao portados."
        else
            status="Matchmaking: "..tostring(reason)
        end
        return
    end
    client=Network.new(options)
    local connected,where=client:connectMatch(result,{
        name=fields[4].value,useTouch=false,isMobile=false,
    })
    if not connected then
        status="Falha nos enderecos da partida: "..tostring(where)
    else
        status="Conectado a "..tostring(where)..
            "; aguardando JoinedMsg..."
    end
end
function love.load()
    love.window.setTitle("LastCircle - Survev Lua (cliente em desenvolvimento)")
    font=love.graphics.newFont(16)
    love.graphics.setFont(font)
    tile=loadImage("assets/survev/img/intro/map_tile.png")
    logo=loadImage("assets/survev/img/survev_logo_full.png")
    selectImage()
    live=LiveDebug.new()
    hud=Hud.new()
    minimap=Minimap.new()
    inventoryPanel=InventoryPanel.new()
    pickupFeedback=PickupFeedback.new()
    equipmentTracker=EquipmentTracker.new()
    demo=OfflineDemo.new()
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
    if key=="f8" then showDebug=not showDebug;return end
    if (screen=="demo" or (screen=="network" and connected())) and
        (key=="i" or key=="tab") then
        inventoryPanel:toggle()
        if inventoryPanel.visible then fireStart=false end
        return
    end
    if (screen=="demo" or screen=="network") and key=="m" then
        minimap:toggleExpanded()
        return
    elseif (screen=="demo" or screen=="network") and key=="n" then
        minimap:toggleVisible()
        return
    end
    if key=="f5" then
        pendingInput:clear()
        fireStart=false
        demo=OfflineDemo.new()
        screen="demo"
        return
    elseif key=="f6" then
        pendingInput:clear()
        fireStart=false
        screen=screen=="network" and "demo" or "network"
        return
    elseif key=="f7" then
        screen=screen=="assets" and "demo" or "assets"
        return
    end
    if key=="escape" then
        pendingInput:clear()
        fireStart=false
        if client and client.connection and client.connection.state=="open" then
            client:close()
            status="Desconectado."
        elseif screen=="network" then
            screen="demo"
        else
            love.event.quit()
        end
        return
    end
    if screen=="demo" then
        if key=="f" then demo:interact()
        elseif key=="r" then demo=OfflineDemo.new()
        elseif key=="g" then demo:toggleGear()
        elseif key=="c" then demo:cycleOutfit()
        elseif key=="1" or key=="2" or key=="3" or key=="4" or key=="5" then
            demo:equip(tonumber(key))
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
        if key=="f1" then gameModeIdx=0;return
        elseif key=="f2" then gameModeIdx=1;return
        elseif key=="f3" then gameModeIdx=2;return end
        if key=="tab" then focus=focus%#fields+1
        elseif key=="return" or key=="kpenter" then
            if love.keyboard.isDown("lshift","rshift") then
                setConnection()
            else
                quickPlay()
            end
        elseif key=="backspace" then fields[focus].value=backspace(fields[focus].value)
        elseif key=="v" and love.keyboard.isDown("lctrl","rctrl") then
            local pasted=love.system.getClipboardText() or ""
            pasted=pasted:gsub("[%c]","")
            fields[focus].value=(fields[focus].value..pasted):sub(1,1500)
        end
        return
    end
    -- The authoritative Survev server accepts inputs only after JoinedMsg.
    local state=client and client:getGameState()
    if not state or not state.joined or state.gameOver then return end
    pendingInput:keypressed(key)
end
function love.wheelmoved(dx,dy)
    local state=client and client:getGameState()
    if screen~="network" or not connected() or not state or
        not state.joined or state.gameOver then return end
    pendingInput:wheelmoved(dy)
end
function love.mousepressed(x,y,button)
    if screen=="demo" then
        -- A click inside an open inventory must not trigger combat.
        if inventoryPanel.visible then return end
        if button==1 then demo:punch() end
        return
    end
    if screen~="network" then return end
    if connected() then
        if inventoryPanel.visible then
            if button==2 then
                local width,height=love.graphics.getDimensions()
                local state=client:getGameState()
                local row=inventoryPanel:hitTest(state,width,height,x,y)
                if row then
                    local packet,reason=client:dropInventoryItem(row.type)
                    inventoryPanel:flash(packet and
                        ("Pedido para soltar "..row.name.." enviado.")
                        or ("Nao enviado: "..tostring(reason)))
                end
            end
            -- Clicking UI never fires a gun or issues an unbound world action.
            return
        end
        if button==1 then
            local state=client:getGameState()
            if state and state.joined and not state.gameOver
                and not state.spectating then
                local width,height=love.graphics.getDimensions()
                local target=Hud.slotAt(state,width,height,x,y)
                if target then
                    local bySlot={
                        Binds.Input.EquipPrimary,Binds.Input.EquipSecondary,
                        Binds.Input.EquipMelee,Binds.Input.EquipThrowable,
                    }
                    pendingInput:queueAction(bySlot[target.slot+1])
                    return
                end
            end
        end
        if button==2 then
            local width,height=love.graphics.getDimensions()
            local target=Hud.hitTest(client:getGameState(),width,height,x,y)
            if target then
                local packet,reason
                if target.kind=="weapon" then
                    packet,reason=client:dropWeaponSlot(target.slot)
                elseif target.kind=="armor" then
                    packet,reason=client:dropArmor(target.field)
                end
                hud:flash(packet and
                    ("Descarte solicitado: "..target.name)
                    or ("Nao enviado: "..tostring(reason)))
                return
            end
        end
        if button==1 then
            local width,height=love.graphics.getDimensions()
            if Hud.containsUi(client:getGameState(),width,height,x,y) then
                return
            end
            fireStart=true
        end
        return
    end
    local w=love.graphics.getWidth()
    local x0=w/2-300
    for i=1,#fields do
        local sy=160+(i-1)*55
        if x>=x0 and x<=x0+600 and y>=sy and y<=sy+39 then
            focus=i
            break
        end
    end
end
local atan2=math.atan2 or math.atan
function love.update(dt)
    inventoryPanel:update(dt)
    hud:update(dt)
    if screen=="demo" then
        local state=demo:getGameState()
        local player=state.objects[state.activeId]
        live.camera.m_pos=player.pos
        live.camera.m_screenWidth,live.camera.m_screenHeight=
            love.graphics.getDimensions()
        local mx,my=love.mouse.getPosition()
        local mouseWorld=live.camera:m_screenToPoint({x=mx,y=my})
        local x=(love.keyboard.isDown("d") and 1 or 0)-
            (love.keyboard.isDown("a") and 1 or 0)
        local y=(love.keyboard.isDown("w") and 1 or 0)-
            (love.keyboard.isDown("s") and 1 or 0)
        demo:update(dt,x,y,mouseWorld)
        live:update(state,dt)
        if os.getenv("LASTCIRCLE_DEMO_SMOKE")=="1" then
            smokeFrames=smokeFrames+1
            -- Exercise both the original fists and a real AK-47 world sprite
            -- in the same real LÖVE2D/OpenGL test, without fake combat.
            if smokeFrames==9 then assert(demo:equip(4)) end
            if smokeFrames==16 then minimap:toggleExpanded() end
            if smokeFrames==20 then
                minimap:toggleExpanded()
                -- CI-only demonstration pickup: uses an actual source Loot
                -- entity and the preview bag capacity, never server combat.
                demo.state.objects[demo.state.activeId].pos={x=353,y=325}
                assert(demo:pickup())
                inventoryPanel:toggle()
            end
            if smokeFrames>=28
                and love.filesystem.getInfo("LastCircle-demo.png")
                and love.filesystem.getInfo("LastCircle-equipped.png")
                and love.filesystem.getInfo("LastCircle-fullmap.png")
                and love.filesystem.getInfo("LastCircle-inventory.png") then
                print("LASTCIRCLE_OFFLINE_DEMO_SUCCESS")
                love.event.quit(0)
            elseif smokeFrames>=120 then
                error("Offline previews failed in real LÖVE2D")
            end
        end
        return
    end
    if not client then return end
    client:poll()
    local world=client:getGameState()
    pickupFeedback:update(world,dt)
    equipmentTracker:update(world,dt)
    if world and world.map then live:update(world,dt) end
    if screen~="network" or not connected() or not client:getGameState()
        or not client:getGameState().joined then return end
    if client:getGameState().gameOver then
        pendingInput:clear()
        fireStart=false
        return
    end
    local state=client:getGameState()
    local player=state.objects[state.activeId]
    if not player or not player.pos then return end
    local msg=Input.new()
    msg.moveLeft=love.keyboard.isDown("a")
    msg.moveRight=love.keyboard.isDown("d")
    msg.moveUp=love.keyboard.isDown("w")
    msg.moveDown=love.keyboard.isDown("s")
    msg.shootStart=fireStart
    msg.shootHold=not inventoryPanel.visible and love.mouse.isDown(1)
    local mx,my=love.mouse.getPosition()
    local pos=live.camera:m_screenToPoint({x=mx,y=my})
    local dx,dy=pos.x-player.pos.x,pos.y-player.pos.y
    local dist=math.sqrt(dx*dx+dy*dy)
    if dist>0.00001 then
        msg.toMouseDir={x=dx/dist,y=dy/dist}
        msg.toMouseLen=math.min(64,dist)
    end
    pendingInput:drain(msg)
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
    g.printf("F5: TESTAR MAPA LOCAL | F6: conectar | F7: voltar | A/D: artes",0,233,w,"center")
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
local function drawDemo(w,h)
    live:draw(demo:getGameState(),w,h)
    hud:draw(demo:getGameState(),w,h)
    InteractionHint.draw(demo:getGameState(),w,h)
    local g=love.graphics
    g.setColor(.025,.07,.06,.92)
    g.rectangle("fill",math.max(0,(w-980)/2),h-167,math.min(980,w),129,9)
    g.setColor(.96,.97,.87)
    g.printf("TESTE LOCAL DO CLIENTE LUA — SEM SERVIDOR",0,h-159,w,"center")
    g.setColor(.75,.88,.78)
    g.printf("WASD mover  •  mouse mirar  •  clique: soco visual  •  F porta",0,h-133,w,"center")
    g.printf("1 Punhos  |  2 Frigideira  |  3 M9  |  4 AK-47  |  5 M9 duplas",0,h-109,w,"center")
    g.printf("G protecao • C roupa • I/TAB inventario • M mapa • R/F5 reiniciar",0,h-86,w,"center")
    g.setColor(.99,.84,.52)
    g.printf(demo.message,0,h-61,w,"center")
    inventoryPanel:draw(demo:getGameState(),w,h)
    minimap:draw(demo:getGameState(),w,h,live.terrainRenderer)
end

local function drawNetwork(w,h)
    local g=love.graphics
    if client and client:getGameState() and client:getGameState().map then
        live:draw(client:getGameState(),w,h,showDebug)
        hud:draw(client:getGameState(),w,h)
    else
        g.clear(.13,.17,.16)
    end
    if connected() then
        local state=client:getGameState()
        InteractionHint.draw(state,w,h)
        inventoryPanel:draw(state,w,h)
        minimap:draw(state,w,h,live.terrainRenderer)
        pickupFeedback:draw(w,h)
        equipmentTracker:draw(w,h)
        ResultsOverlay.draw(state,w,h)
        local statusText="Conexao: "..client.state..
            " | MapMsg: "..tostring(state and state.map and state.map.mapName or "aguardando")..
            " | Atualizacoes: "..tostring(state and state.updateCount or 0)
        if showDebug then
            g.setColor(.95,.97,.87)
            g.printf(statusText,0,128,w,"center")
            g.printf("WASD / mouse: envia InputMsg original; servidor e autoridade.",0,h-88,w,"center")
        end
        return
    end
    g.setColor(.03,.07,.07,.92)
    g.rectangle("fill",w/2-355,40,710,80,8)
    g.setColor(.95,.96,.90)
    g.printf("SURVEV LUA - ENTRAR EM PARTIDA REAL",0,57,w,"center")
    g.setColor(.78,.87,.78)
    g.printf("ENTER: jogar via API | SHIFT+ENTER: URL e token diretos | F5: ambiente local",0,88,w,"center")
    local x=w/2-300
    for i,field in ipairs(fields) do
        local y=160+(i-1)*55
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
    g.printf("F1: modo 0 | F2: modo 1 | F3: modo 2  (modo atual: "..gameModeIdx..")",
        0,505,w,"center")
    g.setColor(.78,.89,.78)
    g.printf("ENTER: POST /api/find_game_v2 + token e URLs do servidor real",
        0,528,w,"center")
    g.printf("HTTPS/WSS: LuaSec e certificado de CA; HTTP/WS so em localhost.",
        0,550,w,"center")
    if status~="" then
        g.setColor(.96,.59,.4)
        g.printf(status,20,592,w-40,"center")
    end
    if client and client.error then
        g.setColor(.98,.42,.38)
        g.printf("Estado: "..client.state.." | "..client.error,
            20,614,w-40,"center")
    end
    g.setColor(.98,.54,.37)
    g.printf("Porte Lua em andamento. Entrar na partida depende do servidor original.",
        0,h-58,w,"center")
end
function love.draw()
    local g=love.graphics
    local w,h=g.getDimensions()
    camera.m_screenWidth,camera.m_screenHeight=w,h
    if screen=="assets" then drawAssets(w,h)
    elseif screen=="demo" then drawDemo(w,h)
    else drawNetwork(w,h) end
    if screen=="demo" and os.getenv("LASTCIRCLE_DEMO_SMOKE")=="1"
        and smokeFrames>=2 and not screenshotRequested then
        screenshotRequested=true
        love.graphics.captureScreenshot("LastCircle-demo.png")
    end
    if screen=="demo" and os.getenv("LASTCIRCLE_DEMO_SMOKE")=="1"
        and smokeFrames>=11 and not equipmentScreenshotRequested then
        equipmentScreenshotRequested=true
        love.graphics.captureScreenshot("LastCircle-equipped.png")
    end
    if screen=="demo" and os.getenv("LASTCIRCLE_DEMO_SMOKE")=="1"
        and smokeFrames>=18 and not mapScreenshotRequested then
        mapScreenshotRequested=true
        love.graphics.captureScreenshot("LastCircle-fullmap.png")
    end
    if screen=="demo" and os.getenv("LASTCIRCLE_DEMO_SMOKE")=="1"
        and smokeFrames>=23 and not inventoryScreenshotRequested then
        inventoryScreenshotRequested=true
        love.graphics.captureScreenshot("LastCircle-inventory.png")
    end
end
