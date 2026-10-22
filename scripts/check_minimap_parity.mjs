/**
 * Golden geometry from pinned client/src/map.ts:getMinimapRender().
 * The comparison is against ORIGINAL TypeScript collider.transform,
 * not only against a Lua-generated object registry.
 */
import {readFile,mkdtemp,writeFile,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [refArg,engine="lua5.4"]=process.argv.slice(2);
if(!refArg)throw Error("Pinned Survev reference required");
const root=resolve(refArg);
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8"))
   .includes("c6185e31fe25a4a07def77a2bb25b1710bda90ac"))
    throw Error("Incorrect original source reference");
const load=async rel=>import(pathToFileURL(resolve(root,rel)).href);
const {MapObjectDefs}=await load("shared/defs/register.ts");
const {mapHelpers}=await load("shared/utils/mapHelpers.ts");
const {math}=await load("shared/utils/math.ts");
const {collider}=await load("shared/utils/collider.ts");
const names=[
    "shack_01","barn_01","warehouse_01","tree_01",
    "stone_01","barrel_01","bush_01","crate_01",
];
const objects=[];
for(let k=0;k<3;k++){
    for(let i=0;i<names.length;i++)objects.push({
        type:names[i],ori:(k+i)%4,scale:.8+(k*.23),
        pos:{x:18+i*29,y:37+k*105+i*4},
    });
}
const source=[];
for(let index=0;index<objects.length;index++){
    const obj=objects[index];
    const def=MapObjectDefs.typeToDef(obj.type);
    const shapes=def.map?.shapes?.length
        ?def.map.shapes
        :[{
            collider:def.type==="obstacle" ? def.collision
                :(def.ceiling.zoomRegions[0]?.zoomIn||
                  mapHelpers.getBoundingCollider(obj.type)),
            scale:def.map.scale??1,color:def.map.color
        }];
    const zIdx=def.type==="building"?750+(def.zIdx||0):(def.img.zIdx||0);
    for(const shape of shapes){
        const result=collider.transform(
            shape.collider,obj.pos,math.oriToRad(obj.ori),obj.scale);
        source.push({
            objType:obj.type,type:result.type,collider:result,
            color:shape.color,scale:shape.scale??1,zIdx,index:index+1,
        });
    }
}
source.sort((a,b)=>a.zIdx-b.zIdx||a.index-b.index);
function lua(v){
    if(v==null)return "nil";
    if(typeof v==="boolean")return String(v);
    if(typeof v==="string")return JSON.stringify(v);
    if(typeof v==="number"){
        if(!Number.isFinite(v))throw Error("NaN source value");
        return v.toPrecision(17);
    }
    if(Array.isArray(v))return "{"+v.map(lua).join(",")+"}";
    return "{"+Object.entries(v).map(([k,p])=>"["+lua(k)+"]="+lua(p)).join(",")+"}";
}
const dir=await mkdtemp(join(tmpdir(),"survev-mini-"));
try{
    const file=join(dir,"fixtures.lua");
    await writeFile(file,"return "+lua({objects,source})+"\n");
    const p=spawnSync(engine,["tests/minimap_parity.lua",file],{
        encoding:"utf8",cwd:process.cwd(),maxBuffer:2e6,
    });
    process.stdout.write(p.stdout);process.stderr.write(p.stderr);
    if(p.error)throw p.error;
    if(p.status!==0)throw Error("Survev minimap fidelity mismatch");
}finally{await rm(dir,{recursive:true,force:true});}
