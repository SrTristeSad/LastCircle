/**
 * Export authoritative obstacle sprite metadata from pinned Survev MapObjectDefs,
 * resolving image keys against actual upstream public/img/ files.
 * Builds src/survev/map_obstacle_art.lua; NEVER invents missing images.
 */
import { readFile,writeFile,mkdir,readdir } from "node:fs/promises";
import { resolve,join,relative,dirname,extname,basename } from "node:path";
import { pathToFileURL } from "node:url";
const [refArg,outArg]=process.argv.slice(2);
if(!refArg||!outArg)throw Error("usage: generate_obstacle_art.mjs <reference> <output>");
const root=resolve(refArg),pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pin))
    throw Error("Survev upstream SHA mismatch");
const { MapObjectDefs }=await import(pathToFileURL(resolve(root,"shared/defs/register.ts")).href);
const imageRoot=resolve(root,"client/public/img");
const fileMap=new Map();
async function walk(folder) {
    for(const item of await readdir(folder,{withFileTypes:true})) {
        const abs=join(folder,item.name);
        if(item.isDirectory()) await walk(abs);
        else if(item.isFile()&&/\.(svg|png|webp)$/i.test(item.name)) {
            const id=basename(item.name,extname(item.name));
            const rel=relative(imageRoot,abs).replaceAll("\\","/");
            const normalized=rel.replace(/\.(svg|webp)$/i,".png");
            fileMap.set(id,[...(fileMap.get(id)||[]),normalized]);
        }
    }
}
await walk(imageRoot);
function assetFor(key) {
    if(!key || key==="none") return null;
    const basenameKey=key.replace(/\.img$/,"");
    const candidates=fileMap.get(basenameKey)||[];
    if(candidates.length===1)return candidates[0];
    if(candidates.length>1) {
        const exact=candidates.find(x=>x==="map/"+basenameKey+".png");
        if(exact)return exact;
        throw Error("ambiguous original sprite "+key+": "+candidates.join(", "));
    }
    return null;
}
const nums={
    imgScale: d=>d.img.scale??1,
    alpha: d=>d.img.alpha??1,
    tint: d=>d.img.tint??0xffffff,
    zIdx: d=>d.img.zIdx??0,
};
const all={};
let obstacleCount=0, resolved=0,missing=new Set();
const assetRefs=new Set();
for(const type of MapObjectDefs.getAllTypes()) {
    const d=MapObjectDefs.typeToDef(type);
    if(d.type!=="obstacle")continue;
    obstacleCount++;
    const picture=d.img.sprite || null;
    const residue=d.img.residue || null;
    const buttonOn=d.button?.useImg || null;
    const buttonOff=d.button?.offImg || null;
    for(const str of [picture,residue,buttonOn,buttonOff]){
        if(!str || str==="none")continue;
        if(assetFor(str))assetRefs.add(str);
        else missing.add(str);
    }
    all[type]={
        sprite:picture,
        asset:assetFor(picture),
        residue:assetFor(residue),
        buttonOn:assetFor(buttonOn),
        buttonOff:assetFor(buttonOff),
        imageScale:nums.imgScale(d),
        alpha:nums.alpha(d),
        tint:nums.tint(d),
        zIdx:nums.zIdx(d),
        mirrorX:d.img.mirrorX??false,
        mirrorY:d.img.mirrorY??false,
        randomRotation:d.img.randomRotation??false,
        doorAnchor:d.door?.spriteAnchor || {x:.5,y:.5},
        // Original collisionHelpers.ts checks these exact attributes.
        collision:d.collision,
        collidable:d.collidable,
        height:d.height,
        isWindow:!!d.isWindow,
        isWall:!!d.isWall,
        door:d.door ? {
            slideToOpen:!!d.door.slideToOpen,
            slideOffset:d.door.slideOffset,
            openSpeed:d.door.openSpeed,
            openOneWay:d.door.openOneWay,
            casing:d.door.casingImg ? {
                asset:assetFor(d.door.casingImg.sprite),
                sprite:d.door.casingImg.sprite,
                pos:d.door.casingImg.pos,
                scale:d.door.casingImg.scale,
                tint:d.door.casingImg.tint,
                alpha:d.door.casingImg.alpha,
            } : null,
        } : null,
    };
    if(assetFor(picture))resolved++;
}
const q=(v)=>v===null?"nil":typeof v==="string"?JSON.stringify(v):
    typeof v==="boolean"?String(v):
    typeof v==="number"?(Number.isFinite(v)?String(v):(()=>{throw Error("not finite")})()):
    typeof v==="object"?"{"+Object.entries(v).map(([k,value])=>"["+q(k)+"]="+q(value)).join(",")+"}":
    (()=>{throw Error("bad metadata")})();
const lines=[
    "-- Auto-generated from survev/survev MapObjectDefs + actual public/img manifest.",
    "-- SHA "+pin+"; GPL-3.0-or-later; no substitute graphics.",
    "-- Missing references remain nil, never fabricated.",
    "return {"
];
for(const [type,metadata] of Object.entries(all)) {
    lines.push("    ["+q(type)+"] = "+q(metadata)+",");
}
lines.push("}\n");
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),lines.join("\n"));
console.log("Obstacle definitions:",obstacleCount,"primary sprites resolved:",resolved,
    "unique art IDs resolved:",assetRefs.size,
    "missing referenced images:",missing.size);
if(missing.size>0)console.log("Unresolved original references:",[...missing].slice(0,50).join(", "));
