/**
 * Original Survev Building image positioning reference fixtures.
 * Uses ORIGINAL TypeScript MapObjectDefs + client/src/camera.ts +
 * v2.rotate + math.oriToRad; compares actual Lua building commands.
 */
import {readFile,mkdtemp,writeFile,rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {resolve,join} from "node:path";
import {spawnSync} from "node:child_process";
import {pathToFileURL} from "node:url";
const [upstreamArg, interpreter="lua5.4"]=process.argv.slice(2);
if(!upstreamArg)throw Error("reference checkout argument missing");
const root=resolve(upstreamArg);
const pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pin))throw Error("reference unpinned");
const load=async path=>await import(pathToFileURL(resolve(root,path)).href);
const {MapObjectDefs}=await load("shared/defs/register.ts");
const {v2}=await load("shared/utils/v2.ts");
const {math}=await load("shared/utils/math.ts");
const {Camera}=await load("client/src/camera.ts");
const camera=new Camera();
camera.m_pos=v2.create(300,360);
camera.m_screenWidth=1024;camera.m_screenHeight=768;
const buildings=[
    {__type:6,__id:20,type:"shack_01",pos:{x:300,y:360},ori:0,layer:0,
        ceilingDead:false,ceilingDamaged:false},
    {__type:6,__id:21,type:"bank_01",pos:{x:310,y:355},ori:1,layer:0,
        ceilingDead:false,ceilingDamaged:false},
    {__type:6,__id:22,type:"shack_01",pos:{x:290,y:380},ori:2,layer:0,
        ceilingDead:true,ceilingDamaged:false},
    {__type:6,__id:23,type:"barn_basement_floor_01",pos:{x:340,y:400},ori:3,layer:1,
        ceilingDead:false,ceilingDamaged:false},
];
function cmdList(phase){
  const items=[];
  for(const obj of buildings){
    const def=MapObjectDefs.typeToDef(obj.type,"building");
    const pictures=phase==="floor"?def.floor.imgs:def.ceiling.imgs;
    for(let i=0;i<pictures.length;i++){
      const img=pictures[i];
      if(phase==="ceiling"&&obj.ceilingDamaged&&img.removeOnDamaged) continue;
      const off=v2.rotate(img.pos||v2.create(0,0),math.oriToRad(obj.ori));
      const point=camera.m_pointToScreen(v2.add(obj.pos,off));
      const s=camera.m_pixels(img.scale);
      items.push({
        x:point.x,y:point.y,
        angle:-math.oriToRad(obj.ori)+math.oriToRad(img.rot||0),
        sx:img.mirrorX?-s:s,
        sy:img.mirrorY?-s:s,
        alpha:img.alpha,tint:img.tint,
        zOrd:phase==="ceiling"?750-(def.zIdx||0):(def.zIdx||0),
        zIdx:obj.__id*100+i,type:obj.type,ownerId:obj.__id,
        sprite:img.sprite
      });
    }
  }
  items.sort((a,b)=>a.zOrd-b.zOrd||a.zIdx-b.zIdx||a.ownerId-b.ownerId);
  return items;
}
const fixture={
   camera:{m_pos:camera.m_pos,m_screenWidth:camera.m_screenWidth,
       m_screenHeight:camera.m_screenHeight,m_ppu:camera.m_ppu,m_zoom:camera.m_zoom},
   objects:buildings,
   floor:cmdList("floor"),
   ceiling:cmdList("ceiling"),
};
function lua(val){
    if(val==null)return "nil";
    if(typeof val==="number"){
        if(!Number.isFinite(val)) throw Error("bad numeric fixture");
        return val.toPrecision(17);
    }
    if(typeof val==="string")return JSON.stringify(val);
    if(typeof val==="boolean")return String(val);
    if(Array.isArray(val))return "{"+val.map(lua).join(",")+"}";
    return "{"+Object.entries(val).map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
}
const temp=await mkdtemp(join(tmpdir(),"survev-build-"));
try {
    const file=join(temp,"build.lua");
    await writeFile(file,"return "+lua(fixture)+"\n");
    const result=spawnSync(interpreter,["tests/building_parity.lua",file],{
        encoding:"utf8",cwd:process.cwd(),maxBuffer:3*1024*1024
    });
    process.stdout.write(result.stdout);process.stderr.write(result.stderr);
    if(result.error)throw result.error;
    if(result.status!==0)throw Error("Lua original Building sprite placement mismatch");
}finally{await rm(temp,{recursive:true,force:true});}
