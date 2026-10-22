-- Source: original client/src/objects/obstacle.ts render() and renderer.ts.
-- Ground high obstacles move to stairs layer 2; their sprites are
-- clipped by StructureDef masks. Dead obstacle residue belongs at z=5.
local Art=require("src.survev.obstacle_art_renderer")
local Meta=require("src.survev.map_obstacle_art")
local Camera=require("src.survev.camera")
local Type=require("src.survev.object_serialize_fns").Type
local Structure=require("src.survev.structure_layer")
local function near(a,b)
    assert(math.abs(a-b)<.00001,
        tostring(a).." not "..tostring(b))
end
local ground={__id=1,layer=0,pos={x=0,y=0}}
local underground={__id=2,layer=1,pos={x=0,y=0}}
local tree={
    __type=Type.Obstacle,__id=23,type="tree_01",
    pos={x=0,y=0},scale=1,ori=0,layer=0,
}
local dead={
    __type=Type.Obstacle,__id=24,type="tree_01",
    pos={x=1,y=0},scale=1,ori=0,layer=0,dead=true,
}
local bush={
    __type=Type.Obstacle,__id=25,type="bush_01",
    pos={x=2,y=0},scale=1.2,ori=0,layer=0,
}
local barrel={
    __type=Type.Obstacle,__id=26,type="barrel_01",
    pos={x=3,y=0},scale=1,ori=0,layer=0,
}
local order=Art.visualOrder(Meta.tree_01,tree,ground)
assert(order.high and order.layer==2 and order.z==900)
assert(order.zIdx==1000*65535+23)
local bushOrder=Art.visualOrder(Meta.bush_01,bush,ground)
assert(bushOrder.high and bushOrder.z==160)
near(bushOrder.zIdx,1200*65535+25)
assert(Art.visualOrder(Meta.barrel_01,barrel,ground).z==10)
local deadOrder=Art.visualOrder(Meta.tree_01,dead,ground)
assert(not deadOrder.high and deadOrder.z==5 and deadOrder.layer==0)
assert(not Art.visualOrder(Meta.tree_01,tree,underground).high)
assert(Art.visualOrder(Meta.tree_01,tree,underground).z==800)
tree.layer=2
assert(not Art.visualOrder(Meta.tree_01,tree,ground).high)
tree.layer=0
-- The pinned source has one original mask for bunker_structure_01.
local building={__id=30,__type=Type.Structure,
    type="bunker_structure_01",pos={x=0,y=0},ori=0}
local objects={[23]=tree,[24]=dead,[25]=bush,[26]=barrel,[30]=building}
local camera=Camera.new()
camera.m_pos={x=0,y=0}
camera.m_screenWidth,camera.m_screenHeight=1280,720
local original=Structure.snapshot(objects)
assert(#original==1 and #original[1].mask==1)
local stencilCalls={}
local pixelRects={}
local draws={}
local stencilActive=false
love={
    filesystem={getInfo=function() return true end},
    graphics={
        newImage=function(path)
            local img={name=path}
            function img:getDimensions()return 80,80 end
            function img:setFilter()end
            return img
        end,
        setColor=function()end,
        draw=function(image,x,y)
            draws[#draws+1]={img=image.name,x=x,y=y,
                active=stencilActive}
        end,
        rectangle=function(kind,x,y,w,h)
            assert(kind=="fill")
            pixelRects[#pixelRects+1]={x=x,y=y,w=w,h=h}
        end,
        stencil=function(callback,kind,ref)
            assert(kind=="replace" and ref==1)
            stencilCalls[#stencilCalls+1]="stencil"
            callback()
        end,
        setStencilTest=function(compare,value)
            if compare then
                assert(compare=="equal" and value==0)
                stencilActive=true
                stencilCalls[#stencilCalls+1]="enable"
            else
                stencilActive=false
                stencilCalls[#stencilCalls+1]="disable"
            end
        end,
    }
}
local renderer=Art.new()
renderer:draw(objects,camera,1280,720,"main","belowPlayer",ground)
assert(#draws==2,"dead tree residue and barrel render below player")
assert(draws[1].img:find("tree%-res") and
    draws[2].img:find("barrel"),"dead z=5 precedes live z=10")
renderer:draw(objects,camera,1280,720,"main","aboveRoof",ground)
assert(#draws==2,"ground high trees are deferred to upper layer")
renderer:draw(objects,camera,1280,720,"main","stairsOverlay",ground)
assert(#draws==4)
assert(draws[3].img:find("bush") and draws[4].img:find("tree"))
assert(draws[3].active and draws[4].active)
assert(#pixelRects==1)
local m=original[1].mask[1]
local a,b=camera:m_pointToScreen(m.min),camera:m_pointToScreen(m.max)
near(pixelRects[1].x,math.min(a.x,b.x))
near(pixelRects[1].y,math.min(a.y,b.y))
near(pixelRects[1].w,math.abs(a.x-b.x))
near(pixelRects[1].h,math.abs(a.y-b.y))
assert(#stencilCalls==3 and stencilCalls[3]=="disable")
assert(not stencilActive,"no mask leak into UI/HUD")
draws={}
renderer:draw(objects,camera,1280,720,"main","aboveRoof",underground)
assert(#draws==1 and draws[1].img:find("tree"),
    "high ground tree has original z when player is underground")
draws={}
renderer:draw(objects,camera,1280,720,"main","stairsOverlay",underground)
assert(#draws==0,"no high foliage promotion when underground")
-- No structure in world means no stencil; high foliage is still drawn.
objects[30]=nil
draws={}
stencilCalls={}
renderer:draw(objects,camera,1280,720,"main","stairsOverlay",ground)
assert(#draws==2 and #stencilCalls==0)
-- A dead corpse is rendered at low z, never in the overlay, even if
-- the alive type normally z-orders above roofs.
assert(Art.visualOrder(Meta.tree_01,dead,ground).z==5)
print("Survev obstacle dead zOrd, stairs-high layer and exact bunker masking passed")
