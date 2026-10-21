/**
 * Export ALL building floor/ceiling layers from the PINNED original Survev
 * MapObjectDefs and verify sprite source paths against public/img assets.
 * NO substituted art, geometry or offsets.
 *
 * node --experimental-transform-types scripts/generate_building_art.mjs \
 *    _reference/reference/survev src/survev/map_building_art.lua
 */
import {readFile,readdir,writeFile,mkdir} from "node:fs/promises";
import {resolve,join,relative,dirname,extname,basename} from "node:path";
import {pathToFileURL} from "node:url";

const [sourceArg,outArg]=process.argv.slice(2);
if(!sourceArg||!outArg) throw Error("usage: generate_building_art.mjs <ref> <outfile>");
const root=resolve(sourceArg);
const revision="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(revision)){
    throw Error("pinned original Survev revision is not verified");
}
const {MapObjectDefs}=await import(pathToFileURL(resolve(root,"shared/defs/register.ts")).href);
const assetRoot=resolve(root,"client/public/img");
const files=new Map();
async function visit(folder) {
    for(const item of await readdir(folder,{withFileTypes:true})){
        const abs=join(folder,item.name);
        if(item.isDirectory())await visit(abs);
        else if(item.isFile()&&/\.(svg|png|webp)$/i.test(item.name)){
            const id=basename(item.name,extname(item.name));
            const path=relative(assetRoot,abs).replaceAll("\\","/").replace(/\.(svg|webp)$/i,".png");
            files.set(id,[...(files.get(id)||[]),path]);
        }
    }
}
await visit(assetRoot);

function resolveAsset(key){
    if(!key || key==="none")return null;
    const name=key.endsWith(".img")?key.slice(0,-4):key;
    const options=files.get(name)||[];
    if(options.length===1)return options[0];
    if(options.length===0)return null;
    const prefer=options.find(p=>p==="map/"+name+".png");
    if(prefer)return prefer;
    throw Error("ambiguous Survev sprite "+key+": "+options.join(","));
}
const unresolved=new Set();
let buildingCount=0, totalFloor=0,totalCeiling=0,resolved=0;
const all={};
function image(def){
    const id=def.sprite;
    const asset=resolveAsset(id);
    if(asset)resolved++;
    else if(id&&id!=="none")unresolved.add(id);
    return {
        sprite:id??null,
        asset,
        pos:def.pos??{x:0,y:0},
        rot:def.rot??0,
        scale:def.scale??null,
        alpha:def.alpha??null,
        tint:def.tint??null,
        mirrorX:def.mirrorX??false,
        mirrorY:def.mirrorY??false,
        removeOnDamaged:def.removeOnDamaged??false,
    };
}
for(const name of MapObjectDefs.getAllTypes()){
    const def=MapObjectDefs.typeToDef(name);
    if(def.type!=="building")continue;
    buildingCount++;
    const floor=def.floor.imgs.map(image);
    const ceiling=def.ceiling.imgs.map(image);
    totalFloor+=floor.length;totalCeiling+=ceiling.length;
    const zoomRegions=def.ceiling.zoomRegions.map(region=>({
        zoomIn:region.zoomIn??null,
        zoomOut:region.zoomOut??null,
        zoom:region.zoom??null,
        noZoom:region.noZoom??null
    }));
    const floorSurfaces=def.floor.surfaces.map(surface=>({
        type:surface.type,
        collision:surface.collision,
        data:surface.data??null
    }));
    all[name]={
        zIdx:def.zIdx??0,
        floor,
        ceiling,
        zoomRegions,
        vision:def.ceiling.vision??{},
        floorSurfaces,
        destroyResidue:resolveAsset(def.ceiling.destroy?.residue),
    };
}
function lua(value){
    if(value===null||value===undefined)return "nil";
    if(typeof value==="string")return JSON.stringify(value);
    if(typeof value==="number"){
        if(!Number.isFinite(value))throw Error("non-finite original definition");
        return String(value);
    }
    if(typeof value==="boolean")return String(value);
    if(Array.isArray(value))return "{"+value.map(lua).join(",")+"}";
    return "{"+Object.entries(value).filter(([,v])=>v!==undefined)
        .map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
}
const lines=[
    "-- Generated from ORIGINAL survev/survev MapObjectDefs (GPL-3.0-or-later).",
    "-- Commit "+revision,
    "-- Not hand-built; missing source assets remain nil rather than invented.",
    "return {"
];
for(const [key,def] of Object.entries(all))lines.push("  ["+lua(key)+"]="+lua(def)+",");
lines.push("}\n");
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),lines.join("\n"));
console.log("Original Survev building definitions:",buildingCount,
    "floor images:",totalFloor,"ceiling images:",totalCeiling,
    "resolved sprite layers:",resolved,"unresolved image keys:",unresolved.size);
if(unresolved.size)console.log("Missing original sprites:",[...unresolved].join(", "));
