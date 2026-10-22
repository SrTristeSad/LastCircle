/**
 * Export every Survev StructureDef stair collision and mask from the
 * pinned original MapObjectDefs. Preserve exact colliders, don't guess
 * room or stair geometry. All input is source code at revision c6185e31.
 *
 * node --experimental-transform-types scripts/generate_structure_collision.mjs
 *   _reference/reference/survev src/survev/map_structure_collision.lua
 */
import {readFile,writeFile,mkdir} from "node:fs/promises";
import {resolve,dirname} from "node:path";
import {pathToFileURL} from "node:url";
const [sourceArg,outArg]=process.argv.slice(2);
if(!sourceArg||!outArg)throw Error("usage: generator <source> <output>");
const source=resolve(sourceArg),pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
const origin=await readFile(resolve(source,"../ORIGEM.txt"),"utf8");
if(!origin.includes(pin))throw Error("Survev source pin mismatch");
const {MapObjectDefs}=await import(pathToFileURL(
    resolve(source,"shared/defs/register.ts")).href);
function lua(value){
    if(value==null)return "nil";
    if(typeof value==="number"){
        if(!Number.isFinite(value))throw Error("nonfinite Survev collider");
        return String(value);
    }
    if(typeof value==="string")return JSON.stringify(value);
    if(typeof value==="boolean")return String(value);
    if(Array.isArray(value))return "{"+value.map(lua).join(",")+"}";
    if(typeof value==="object"){
        return "{"+Object.entries(value).filter(([,v])=>v!==undefined)
          .map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
    }
    throw Error("unsupported original collider metadata");
}
const structures={};
let stairs=0,masks=0;
for(const name of MapObjectDefs.getAllTypes()){
    const def=MapObjectDefs.typeToDef(name);
    if(def.type!=="structure")continue;
    const sourceStairs=def.stairs??[],sourceMasks=def.mask??[];
    structures[name]={
        stairs:sourceStairs.map(x=>({
            collision:x.collision,
            lootOnly:!!x.lootOnly,
        })),
        mask:sourceMasks,
    };
    stairs+=sourceStairs.length;
    masks+=sourceMasks.length;
}
if(Object.keys(structures).length<5||stairs<5||masks<1){
    throw Error("incomplete original structure definitions");
}
const lines=[
    "-- Generated from original pinned Survev MapObjectDefs (GPL-3.0-or-later).",
    "-- SHA "+pin+"; stairs/lootOnly/masks are source data, not visual guesses.",
    "return {"
];
for(const [key,value] of Object.entries(structures))
    lines.push("  ["+lua(key)+"]="+lua(value)+",");
lines.push("}\n");
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),lines.join("\n"));
console.log("Original Survev structures:",Object.keys(structures).length,
    "stair colliders:",stairs,"masks:",masks);
