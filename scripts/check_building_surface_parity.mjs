/**
 * Build floor-material parity fixtures using ORIGINAL Survev collider.transform,
 * collider.intersectCircle and client/src/map.ts building surface selection.
 */
import {readFile,writeFile,mkdtemp,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [refArg,lua="lua5.4"]=process.argv.slice(2);
if(!refArg)throw Error("Survev source required");
const root=resolve(refArg),pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pin))throw Error("incorrect upstream");
const load=async file=>await import(pathToFileURL(resolve(root,file)).href);
const {MapObjectDefs}=await load("shared/defs/register.ts");
const {collider}=await load("shared/utils/collider.ts");
const {v2}=await load("shared/utils/v2.ts");
const {math}=await load("shared/utils/math.ts");
const buildings=[
  {__type:6,__id:20,type:"bank_01",pos:{x:170,y:220},ori:1,layer:0},
  {__type:6,__id:21,type:"shack_01",pos:{x:370,y:320},ori:2,layer:0},
  {__type:6,__id:22,type:"barn_basement_floor_01",pos:{x:550,y:410},ori:3,layer:1},
];
const cases=[];
for(const obj of buildings) {
  const def=MapObjectDefs.typeToDef(obj.type,"building");
  for(const surface of def.floor.surfaces){
    for(const col of surface.collision){
      const transformed=collider.transform(col,obj.pos,math.oriToRad(obj.ori),1);
      const pos=transformed.type===0?transformed.pos:
        {x:(transformed.min.x+transformed.max.x)/2,
         y:(transformed.min.y+transformed.max.y)/2};
      for(const layer of [0,1,2,3]){
        cases.push({pos,layer});
      }
      // Exact transformed collider fixture to check rotated building rectangles.
      cases.push({pos,layer:obj.layer,sourceCol:col,
          transformFor:obj.__id,transformed});
    }
  }
}
cases.push(...[
    {pos:{x:0,y:0},layer:0},
    {pos:{x:170,y:220},layer:0},
    {pos:{x:550,y:410},layer:1},
    {pos:{x:550,y:410},layer:2},
    {pos:{x:370,y:320},layer:0},
    {pos:{x:370,y:320},layer:1},
]);
function sourceLookup(point,layer) {
  let surface=null,zIdx=0,ownerId=null;
  const onStairs=!!(layer&2);
  for(const building of buildings) {
    const def=MapObjectDefs.typeToDef(building.type,"building");
    if(def.zIdx>=zIdx && (building.layer===layer || onStairs) &&
      (building.layer!==1 || !onStairs)){
      for(const s of def.floor.surfaces){
        for(const col of s.collision){
          const world=collider.transform(col,building.pos,math.oriToRad(building.ori),1);
          if(collider.intersectCircle(world,point,.0001)){
            zIdx=def.zIdx||0;
            surface=s.type;ownerId=building.__id;
            break;
          }
        }
      }
    }
  }
  return surface?{type:surface,buildingId:ownerId,zIdx}:null;
}
const data={buildings,cases:cases.map(item=>({...item,expected:sourceLookup(item.pos,item.layer)}))};
function luaTable(x){
  if(x==null)return "nil";
  if(typeof x==="boolean")return String(x);
  if(typeof x==="string")return JSON.stringify(x);
  if(typeof x==="number"){
    if(!Number.isFinite(x))throw Error("bad number");
    return x.toPrecision(17);
  }
  if(Array.isArray(x))return "{"+x.map(luaTable).join(",")+"}";
  return "{"+Object.entries(x).map(([k,v])=>"["+luaTable(k)+"]="+luaTable(v)).join(",")+"}";
}
const dir=await mkdtemp(join(tmpdir(),"survev-material-"));
try{
  const file=join(dir,"material.lua");
  await writeFile(file,"return "+luaTable(data)+"\n");
  const r=spawnSync(lua,["tests/building_surface_parity.lua",file],{
    cwd:process.cwd(),encoding:"utf8",maxBuffer:3*1024*1024
  });
  process.stdout.write(r.stdout);process.stderr.write(r.stderr);
  if(r.error)throw r.error;
  if(r.status!==0)throw Error("Survev building material lookup differs from source");
}finally{await rm(dir,{recursive:true,force:true});}
