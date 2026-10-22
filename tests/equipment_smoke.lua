-- Source Survev equipment visual smoke, tested in Lua 5.4 and LuaJIT.
-- Uses ORIGINAL GameObjectDefs-derived material, not artificial icons.
local Cam=require("src.survev.camera")
local Player=require("src.survev.player_renderer")
local Weapons=require("src.survev.equipment_art")
local Outfits=require("src.survev.player_art").outfits
local cam=Cam.new()
cam.m_pos={x=320,y=330}
cam.m_screenWidth,cam.m_screenHeight=960,640
local renderer=Player.new()
local obj={
    __id=1,pos={x=320,y=330},dir={x=1,y=0},
    outfit="outfitBase",scale=1,activeWeapon="fists",
    backpack="backpack02",helmet="helmet02",chest="chest02",
    dead=false,downed=false
}
local function parts()
    local list=assert(renderer:commands(obj,cam,"main"))
    local names,byName={},{}
    for _,p in ipairs(list) do
        names[#names+1]=p.name
        byName[p.name]=p
        assert(type(p.asset)=="string" and p.asset:match("%.png$"),
            "all commands use original source sprites")
    end
    return table.concat(names,","),byName
end
local a,p=parts()
assert(a=="backpack,body,chest,handL,handR,helmet",a)
assert(p.backpack.asset==Outfits.outfitBase.backpackAsset)
assert(p.chest.asset==Weapons.gear.chest02.skin.asset)
assert(p.helmet.asset==Weapons.gear.helmet02.skin.asset)
local pix=cam:m_pixels(1)
local t=pix/(require("src.survev.game_config").player.radius)
assert(math.abs(p.chest.scaleX-t*.25)<1e-10)
assert(math.abs(p.helmet.scaleX-t*.15)<1e-10)
assert(math.abs(p.backpack.scaleX-t*(.4+2*.03)*.5)<1e-10)
local center=cam:m_pointToScreen(obj.pos)
assert(math.abs(p.backpack.x-(center.x-11.5*t))<1e-10)
assert(math.abs(p.helmet.x-(center.x-3.33*t))<1e-10)

obj.activeWeapon="pan"
a,p=parts()
assert(a=="backpack,body,chest,handL,melee,handR,helmet",a)
assert(p.melee.asset==Weapons.weapons.pan.world.asset)
assert(p.melee.tint==Weapons.weapons.pan.world.tint)
assert(math.abs(p.melee.scaleX-pix*Weapons.weapons.pan.world.scale.x)<1e-10)
assert(math.abs(p.melee.rotation-Weapons.weapons.pan.world.rot)<1e-10)

obj.activeWeapon="m9"
a,p=parts()
assert(a=="backpack,body,chest,handL,gunR,handR,helmet",a)
assert(Player.poseFor(obj)=="pistol")
assert(p.gunR.asset==Weapons.weapons.m9.world.asset)
assert(math.abs(p.gunR.scaleX-pix*.5*.5)<1e-10)
assert(math.abs(p.gunR.scaleY-pix*.505*.5)<1e-10)
assert(math.abs(p.gunR.rotation-math.pi*.5)<1e-10)
assert(p.gunR.anchorX==.5 and p.gunR.anchorY==1)
obj.activeWeapon="m9_dual"
a,p=parts()
assert(Player.poseFor(obj)=="dualPistol")
assert(a=="backpack,body,chest,gunL,handL,gunR,handR,helmet",a)
assert(p.gunL and p.gunR and p.gunL.x==p.gunR.x)
obj.activeWeapon="ak47"
a,p=parts()
assert(Player.poseFor(obj)=="rifle")
assert(p.gunR and p.gunR.asset==Weapons.weapons.ak47.world.asset)
assert(p.handL.x>center.x and p.handR.x>center.x)

-- Switching visuals must not change authority for health, ammo or attacks.
obj.downed=true
a,p=parts()
assert(a=="footL,footR,body,chest,handL,handR,helmet",a)
assert(not p.backpack and not p.gunR and not p.melee)
assert(math.abs(p.helmet.x-(center.x+3.33*t))<1e-10)

obj.downed=false
obj.activeWeapon="fists"
obj.backpack="";obj.helmet="";obj.chest=""
a,p=parts()
assert(a=="body,handL,handR",a)
obj.activeWeapon="INVALID_WEAPON"
a,p=parts()
assert(a=="body,handL,handR",a)

local pulls,draws=0,0
love={
    filesystem={getInfo=function(file)
        assert(file:match("^assets/survev/img/"))
        return true
    end},
    graphics={
        newImage=function(file)
            pulls=pulls+1
            local image={name=file}
            function image:setFilter() end
            function image:getDimensions() return 80,80 end
            return image
        end,
        setColor=function(r,g,b,a)
            assert(type(r)=="number" and type(g)=="number" and type(b)=="number")
        end,
        draw=function(img,x,y,rot,sx,sy,ox,oy)
            assert(img and type(x)=="number" and type(sx)=="number")
            draws=draws+1
        end,
    }
}
obj.activeWeapon="m9"
obj.backpack="backpack02";obj.chest="chest02";obj.helmet="helmet02"
local visible=renderer:draw(obj,cam,"main")
assert(visible==7 and draws==7)
local before=pulls
renderer:draw(obj,cam,"main")
assert(pulls==before,"survev equipment images should be cached between frames")
print("Survev equipment: original gun, melee, armour, backpack, helmet, downed layers and image cache passed")
