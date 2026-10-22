-- Source Survev body/hand/foot sprite screen geometry numerical parity.
local Player=require("src.survev.player_renderer")
local Camera=require("src.survev.camera")
local Source=require("src.survev.player_art")
local fixture=assert(loadfile(assert(arg[1])))()
local cam=Camera.new()
cam.m_screenWidth,cam.m_screenHeight=1280,720
cam.m_pos={x=320,y=333}
local gfx=Player.new()
local count=0
local function near(a,b,why)
    assert(type(a)=="number" and type(b)=="number",why)
    assert(math.abs(a-b)<2e-8,
        string.format("%s expected=%.12g got=%.12g",why,b,a))
    count=count+1
end
for idx,item in ipairs(fixture.cases) do
    local actual=assert(gfx:commands(item.world,cam,"main"))
    local expected=item.expected
    assert(#actual==#expected,"case "..idx.." sprite count mismatch")
    for i=1,#expected do
        local a,b=actual[i],expected[i]
        for _,s in ipairs({"x","y","rotation","scale","tint"}) do
            near(a[s],b[s],"case "..idx.." "..i.." "..s)
        end
        assert(a.name==b.name and a.asset==b.asset,
            "original sprite or texture order mismatch case "..idx.." "..i)
    end
end
local outfits=0
for name,o in pairs(Source.outfits) do
    outfits=outfits+1
    for _,path in ipairs({o.baseAsset,o.handLAsset,o.handRAsset,o.footAsset}) do
        assert(type(path)=="string" and path:find("player/",1,true)==1,
            "source outfit texture is not from real player images: "..name)
    end
end
assert(outfits>10 and Source.idlePoses.fists.HandL.pivot.x==14)
assert(Source.sprites.bodyScale==.25 and Source.sprites.handScale==.175)
local unknown,err=gfx:commands({pos={x=0,y=0},outfit="NOT_UPSTREAM"},cam)
assert(not unknown and err:find("unknown upstream outfit"))
assert(#gfx:commands({pos={x=0,y=0},dead=true},cam)==0)

-- GPU smoke with mocked LÖVE Image files. Checks cache and ordered draws.
local draws,loads={},0
love={
  filesystem={getInfo=function() return true end},
  graphics={
    newImage=function(path)
      loads=loads+1
      local img={path=path}
      function img:setFilter(a,b) assert(a=="linear" and b=="linear") end
      function img:getDimensions() return 80,80 end
      return img
    end,
    draw=function(img,x,y,r,sx,sy,ox,oy)
      draws[#draws+1]={img=img,x=x,y=y,r=r,s=sx}
      assert(sx==sy and ox==40 and oy==40)
    end,
    setColor=function() end,
  }
}
gfx:draw(fixture.cases[1].world,cam,"main")
local firstLoads=loads
assert(#draws==3 and firstLoads==2,"body + two reused source hand sprites")
gfx:draw(fixture.cases[1].world,cam,"main")
assert(loads==firstLoads,"cached texture must not be recreated")
print("Original Survev player pose parity:",count,
    "numeric checks,",outfits,"verified outfits; renderer caching OK")
