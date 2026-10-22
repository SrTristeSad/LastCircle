/**
 * Source-equivalent Map.getMinimapRender() metadata.
 * Based on pinned Survev client/src/map.ts and shared/utils/mapHelpers.ts.
 * No approximate shapes, colors or hand-written stand-in structures.
 */
import {readFile,writeFile,mkdir} from "node:fs/promises";
import {resolve,dirname} from "node:path";
import {pathToFileURL} from "node:url";
const [refArg,outArg]=process.argv.slice(2);
if(!refArg||!outArg)throw Error("Usage: generate_minimap_defs.mjs <source> <output>");
const root=resolve(refArg);
const sha="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(sha))
    throw Error("Original Survev source revision mismatch");
const load=async path=>import(pathToFileURL(resolve(root,path)).href);
const {MapObjectDefs}=await load("shared/defs/register.ts");
const {mapHelpers}=await load("shared/utils/mapHelpers.ts");
const defs={};
let skipped=0,shaped=0;
for(const name of MapObjectDefs.getAllTypes()){
    const def=MapObjectDefs.typeToDef(name);
    if(def.type!=="obstacle"&&def.type!=="building")continue;
    const map=def.map;
    // Items without an actual map colour have no visible minimap graphics.
    // The original renderer creates no meaningful colored shape for them.
    if(!map || map.display===false){skipped++;continue;}
    const shapes=[];
    const zIdx=def.type==="building"?750+(def.zIdx||0):def.img.zIdx||0;
    if(map.shapes?.length){
        for(const s of map.shapes){
            if(s.collider&&typeof s.color==="number")shapes.push({
                collider:s.collider,color:s.color,scale:s.scale??1
            });
        }
    }else{
        let col;
        if(def.type==="obstacle")col=def.collision;
        else{
            col=def.ceiling.zoomRegions?.[0]?.zoomIn;
            if(!col)col=mapHelpers.getBoundingCollider(name);
        }
        if(col && typeof map.color==="number")shapes.push({
            collider:col,color:map.color,scale:map.scale??1
        });
    }
    if(shapes.length){defs[name]={zIdx,shapes};shaped++;}
    else skipped++;
}
function lua(x){
  if(x==null)return "nil";
  if(typeof x==="boolean")return String(x);
  if(typeof x==="string")return JSON.stringify(x);
  if(typeof x==="number"){
    if(!Number.isFinite(x))throw Error("Nonfinite source data");
    return x.toPrecision(17);
  }
  if(Array.isArray(x))return "{"+x.map(lua).join(",")+"}";
  return "{"+Object.entries(x).map(([key,val])=>"["+lua(key)+"]="+lua(val)).join(",")+"}";
}
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),
  "-- Auto-generated from Survev Map.getMinimapRender; GPL-3.0-or-later\n"+
  "-- Pinned upstream "+sha+"; map geometry/color preserved.\n"+
  "return "+lua(defs)+"\n");
console.log("Survev minimap source definitions:",shaped,"with real graphic shapes;",
    skipped,"invisible or colorless");
if(shaped<100)throw Error("Minimap defs unexpectedly incomplete");
