/**
 * Generate exact Survev biome palette and official map IDs from MapDefs.
 * TypeScript source of truth: shared/defs/mapDefs.ts of PINNED upstream.
 *
 * node --experimental-transform-types scripts/generate_map_colors.mjs
 *     _reference/reference/survev src/survev/map_colors.lua
 */
import { readFile,writeFile,mkdir } from "node:fs/promises";
import { dirname,resolve } from "node:path";
import { pathToFileURL } from "node:url";
const [rootArg,outArg]=process.argv.slice(2);
if(!rootArg||!outArg)throw Error("usage: generate_map_colors.mjs <ref root> <lua file>");
const root=resolve(rootArg);
const expected="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(expected)) {
    throw Error("unrecognized Survev revision");
}
const { MapDefs }=await import(pathToFileURL(resolve(root,"shared/defs/mapDefs.ts")).href);
function q(s) {return JSON.stringify(s)}
const entries=Object.entries(MapDefs).sort((a,b)=>a[0].localeCompare(b[0]));
const lines=[
    "-- Generated DIRECTLY from survev/survev shared/defs/mapDefs.ts",
    "-- Commit: "+expected+"; GPL-3.0-or-later",
    "-- Colors are 0xRRGGBB numbers; no visual approximations.",
    "return {"
];
for(const [name,def] of entries){
    lines.push("    ["+q(name)+"] = {");
    lines.push("        mapId = "+def.mapId+",");
    lines.push("        valueAdjust = "+def.biome.valueAdjust+",");
    lines.push("        riverShore = "+q(def.biome.sound.riverShore)+",");
    lines.push("        colors = {");
    for(const [key,val] of Object.entries(def.biome.colors)){
        if(!Number.isInteger(val)||val<0||val>0xffffff)throw Error(name+" color "+key+" invalid: "+val);
        lines.push("            ["+q(key)+"] = 0x"+val.toString(16).padStart(6,"0")+",");
    }
    lines.push("        },");
    lines.push("        atlases = {"+def.assets.atlases.map(q).join(",")+"},");
    lines.push("    },");
}
lines.push("}\n");
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),lines.join("\n"));
console.log("Generated "+entries.length+" original map palettes: "+entries.map(([k])=>k).join(", "));
