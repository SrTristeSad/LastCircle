-- Survev client/src/objects/player.ts basic BODY/HANDS/FEET pass.
-- Original source: updateVisuals(), updateRotation(), render(); idle poses
-- generated from client/src/animData.ts, tints/skins from outfitDefs.ts.
-- Ports source armour/backpacks, melee and gun WORLD sprites with their
-- actual transforms. Shot recoil uses server shotFx; water masks and final PIXI
-- layer sorting remain separate and are NOT simulated.
local Metadata=require("src.survev.player_art")
local Equipment=require("src.survev.equipment_art")
local Config=require("src.survev.game_config")
local Palettes=require("src.survev.map_colors")
local V=require("src.survev.v2")
local Player={}
Player.__index=Player

local function color(color)
    return math.floor(color/65536)%256/255,
        math.floor(color/256)%256/255,
        color%256/255
end
-- Source client/src/objects/player.ts:selectIdlePose.
function Player.poseFor(obj)
    if obj.downed then return "downed" end
    local item=Equipment.weapons[obj.activeWeapon or "fists"]
    if not item then return "fists" end
    if item.idlePose and Metadata.idlePoses[item.idlePose] then
        return item.idlePose
    end
    if item.type=="gun" then
        if item.pistol then return item.isDual and "dualPistol" or "pistol" end
        if item.isBullpup then return "bullpup" end
        if item.isLauncher then return "launcher" end
        if item.isMinigun then return "minigun" end
        return item.isDual and "dualRifle" or "rifle"
    end
    return "fists"
end
-- Survev client/src/animData.ts:Animations.fists hand-R keyframes.
-- This reproduces the visible idle -> punch -> idle pose ONLY. It never
-- creates a hit, damage, particles or sound without a real game server.
local function mix(a,b,t) return a+(b-a)*t end
function Player.fistPose(t)
    local frames=Metadata.animations and Metadata.animations.fists
    if not frames or type(t)~="number" or t<0 then return nil end
    if t>=frames[#frames].time then return nil end
    local start,finish=frames[1],frames[2]
    for idx=2,#frames do
        if t<=frames[idx].time then
            start,finish=frames[idx-1],frames[idx]
            break
        end
    end
    local weight=(t-start.time)/(finish.time-start.time)
    local a,b=start.handR,finish.handR
    return {
        pivot={x=mix(a.pivot.x,b.pivot.x,weight),
            y=mix(a.pivot.y,b.pivot.y,weight)},
        pos={x=mix(a.pos.x,b.pos.x,weight),
            y=mix(a.pos.y,b.pos.y,weight)},
        rot=mix(a.rot,b.rot,weight),
    }
end
local function worldPose(pose,bodyCenter,bodyRotation,bodyScale)
    local boneRot=pose.rot or 0
    local original=V.add(pose.pos,
        V.rotate(pose.pivot,boneRot))
    local offset=V.rotate(V.mul(original,bodyScale),bodyRotation)
    return V.add(bodyCenter,offset),bodyRotation+boneRot
end
function Player.new()
    return setmetatable({images={},missing={},drawn=0,unavailable=0},Player)
end
function Player:load(path)
    if self.images[path]~=nil then return self.images[path] or nil end
    local full="assets/survev/img/"..path
    if not love.filesystem.getInfo(full) then
        self.images[path]=false
        self.missing[full]=true
        return nil
    end
    local ok,img=pcall(love.graphics.newImage,full)
    if not ok then
        self.images[path]=false
        self.missing[full]=true
        return nil
    end
    img:setFilter("linear","linear")
    self.images[path]=img
    return img
end
function Player:commands(obj,camera,mapName,animation,recoil)
    if not obj or not obj.pos or obj.dead then return {} end
    local outfit=Metadata.outfits[obj.outfit or "outfitBase"]
    if not outfit then
        return nil,"unknown upstream outfit: "..tostring(obj.outfit)
    end
    local yaw=math.atan2 or math.atan
    local heading=obj.dir or {x=1,y=0}
    local rad=-yaw(heading.y,heading.x)
    local center=camera:m_pointToScreen(obj.pos)
    -- Original player.ts: camera.m_pixels(1) * (m_bodyRad / player.radius).
    local bodyScale=camera:m_pixels(1)*(obj.scale or 1)/Config.player.radius
    local poses=assert(Metadata.idlePoses[Player.poseFor(obj)])
    local palette=Palettes[mapName or "main"]
    local ghillieColor=palette and palette.colors.playerGhillie
    local primary=outfit.ghillie and ghillieColor or outfit.baseTint
    local hand=outfit.ghillie and ghillieColor or outfit.handTint
    local foot=outfit.ghillie and ghillieColor or outfit.footTint
    local output={}
    local function append(name,path,tint,scale,pose,extraRotation)
        local at,angle=center,rad
        if pose then at,angle=worldPose(pose,center,rad,bodyScale) end
        output[#output+1]={
            name=name,asset=path,x=at.x,y=at.y,
            rotation=angle+(extraRotation or 0),
            scale=bodyScale*scale,tint=tint,
            ownerId=obj.__id,
        }
    end
    -- Screen-space commands retain ORIGINAL PIXI bodyContainer ordering.
    -- Only layers whose metadata and source art have been verified render.
    local function raw(name,asset,tint,point,angle,sx,sy,ax,ay)
        if not asset then return end -- never generate stand-in pixels
        output[#output+1]={
            name=name,asset=asset,tint=tint,ownerId=obj.__id,
            x=point.x,y=point.y,rotation=angle,
            scaleX=sx,scaleY=sy,anchorX=ax or .5,anchorY=ay or .5,
        }
    end
    local function localPoint(offset)
        return V.add(center,V.rotate(V.mul(offset,bodyScale),rad))
    end
    -- Backpack behind the body (Survev m_getBagLevel / updateVisuals).
    local bag=Equipment.gear[obj.backpack or ""]
    if bag and bag.type=="backpack" and bag.level>0
        and not obj.downed and not outfit.ghillie then
        local offsets={10.25,11.5,12.75}
        local offset=offsets[math.min(bag.level,#offsets)]
        local scale=(.4+bag.level*.03)*.5*bodyScale
        raw("backpack",outfit.backpackAsset,outfit.backpackTint,
            localPoint({x=-offset,y=0}),rad,scale,scale)
    end
    if obj.downed then
        if poses.FootL then
            append("footL",outfit.footAsset,foot,Metadata.sprites.footScale,
                poses.FootL,math.pi*.5)
        end
        if poses.FootR then
            append("footR",outfit.footAsset,foot,Metadata.sprites.footScale,
                poses.FootR,math.pi*.5)
        end
    end
    append("body",outfit.baseAsset,primary,Metadata.sprites.bodyScale)
    -- Chest armour is layered over the body using its own original tint.
    local chest=Equipment.gear[obj.chest or ""]
    if chest and chest.type=="chest" and chest.skin and not outfit.ghillie then
        local s=bodyScale*.25
        raw("chest",chest.skin.asset,chest.skin.baseTint,center,rad,s,s)
    end

    local weap=Equipment.weapons[obj.activeWeapon or "fists"]
    local world=(not obj.downed) and weap and weap.world or nil
    local leftPose=poses.HandL
    local rightPose=poses.HandR
    -- Original player.ts blends server animSeq-triggered bones with idle pose.
    -- Only source-verified keyframes are overridden; unknown types stay idle.
    if animation and not obj.offlinePreview then
        leftPose=animation.HandL or leftPose
        rightPose=animation.HandR or rightPose
    end
    if obj.offlinePreview and (not obj.activeWeapon or obj.activeWeapon=="fists") and rightPose then
        rightPose=Player.fistPose(obj.previewFistTicker) or rightPose
    end
    -- player.ts:updateRotation: gunRecoilL/R move the corresponding hand
    -- container by -recoil*1.125 along its local X axis. The gun is parented
    -- to that hand, so both the gun sprite and fingers inherit the offset.
    -- Never mutate shared idle pose metadata or the inbound packet.
    local function shifted(pose,amount)
        if not pose or type(amount)~="number" or amount<=0 then
            return pose
        end
        return {
            pos={x=(pose.pos and pose.pos.x or 0)-amount*1.125,
                 y=(pose.pos and pose.pos.y or 0)},
            pivot=pose.pivot,rot=pose.rot,
        }
    end
    if recoil and world and weap.type=="gun" and not obj.downed
        and not obj.offlinePreview then
        leftPose=shifted(leftPose,recoil.left)
        rightPose=shifted(rightPose,recoil.right)
    end
    -- Source player.ts:updateRotation: left-hand gun-specific offset.
    if world and weap.type=="gun" and leftPose and world.leftHandOffset then
        leftPose={
            pos=V.add(leftPose.pos,world.leftHandOffset),
            pivot=leftPose.pivot,rot=leftPose.rot,
        }
    end
    local function drawGun(side,pose)
        if not (world and world.asset and pose) then return end
        local handPos,handAngle=worldPose(pose,center,rad,bodyScale)
        local dx,dy=weap.isDual and -5.95 or -4.25,
            weap.isDual and 0 or -1.75
        if world.gunOffset then
            dx=dx+world.gunOffset.x
            dy=dy+world.gunOffset.y
        end
        local origin=V.add(handPos,
            V.rotate(V.mul({x=dx,y=dy},bodyScale),handAngle))
        local angle=handAngle+math.pi*.5
        local pix=camera:m_pixels(1)
        local function mag()
            if not (world.mag and world.mag.asset) then return end
            local pos=V.add(origin,
                V.rotate(V.mul(world.mag.pos or {x=0,y=0},pix),angle))
            raw("gunMag"..side,world.mag.asset,0xffffff,
                pos,angle,pix*.25,pix*.25)
        end
        if world.mag and not world.mag.top then mag() end
        -- Original Gun.setType(): gunBarrel anchor=(.5,1)
        raw("gun"..side,world.asset,world.tint,origin,angle,
            pix*world.scale.x*.5,pix*world.scale.y*.5,.5,1)
        if world.mag and world.mag.top then mag() end
    end
    local function drawMelee(pose)
        if not (world and world.asset and world.pos and pose) then return end
        -- In original player.ts the melee sprite lives inside handRContainer,
        -- with pivot=-world.pos and own rotation=world.rot. MeleeR idle bone
        -- is identity; this preserves its exact PIXI nested transformation.
        local centerHand,handAngle=worldPose(pose,center,rad,bodyScale)
        local angle=handAngle+(world.rot or 0)
        local centerSprite=V.add(centerHand,
            V.rotate(V.mul(world.pos,bodyScale),angle))
        local pix=camera:m_pixels(1)
        raw("melee",world.asset,world.tint,centerSprite,angle,
            pix*world.scale.x,pix*world.scale.y)
    end

    -- Hand containers: gun sprite below hand by default, unless handsBelow;
    -- melee image above hand only if worldImg.renderOnHand is true.
    local function drawHand(side,pose)
        if not pose then return end
        local drawGunSide=world and weap.type=="gun"
            and (side=="R" or weap.isDual)
        local drawMeleeSide=world and weap.type=="melee" and side=="R"
        if drawGunSide and not world.handsBelow then drawGun(side,pose) end
        if drawMeleeSide and not world.renderOnHand then drawMelee(pose) end
        append("hand"..side,side=="L" and outfit.handLAsset or outfit.handRAsset,
            hand,Metadata.sprites.handScale,pose)
        if drawMeleeSide and world.renderOnHand then drawMelee(pose) end
        if drawGunSide and world.handsBelow then drawGun(side,pose) end
    end
    if weap and weap.type=="melee" and world and world.leftHandOntop then
        drawHand("R",rightPose)
        drawHand("L",leftPose)
    else
        drawHand("L",leftPose)
        drawHand("R",rightPose)
    end

    -- Helmet above body and hands, using source -3.33/+3.33 local offset.
    local helmet=Equipment.gear[obj.helmet or ""]
    if helmet and helmet.type=="helmet" and helmet.skin and not outfit.ghillie then
        local img=helmet.skin
        local s=bodyScale*(img.spriteScale or .15)
        local x=obj.downed and 3.33 or -3.33
        raw("helmet",img.asset,img.baseTint,localPoint({x=x,y=0}),
            rad,s,s)
    end
    return output
end

function Player:draw(obj,camera,mapName,animation,recoil)
    local commands,err=self:commands(obj,camera,mapName,animation,recoil)
    if not commands then
        self.unavailable=self.unavailable+1
        return 0,err
    end
    local n=0
    for _,item in ipairs(commands) do
        local tex=self:load(item.asset)
        if tex then
            local width,height=tex:getDimensions()
            love.graphics.setColor(color(item.tint))
            love.graphics.draw(tex,item.x,item.y,item.rotation,
                item.scaleX or item.scale,item.scaleY or item.scale,
                width*(item.anchorX or .5),height*(item.anchorY or .5))
            n=n+1
        else
            self.unavailable=self.unavailable+1
        end
    end
    love.graphics.setColor(1,1,1,1)
    self.drawn=self.drawn+n
    return n
end
return Player
