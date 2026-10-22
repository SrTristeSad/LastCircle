/**
 * Export ORIGINAL Survev loot and inventory metadata for LÖVE.
 * Source: GameObjectDefs (itemDef.lootImg), GameConfig.lootRadius,
 * GameConfig.bagSizes, and client/src/objects/loot.ts @ pinned revision.
 * Never fabricate replacement images, content names or carrying capacity.
 */
import {readFile,readdir,writeFile,mkdir} from "node:fs/promises";
import {resolve,join,relative,basename,extname,dirname} from "node:path";
import {pathToFileURL} from "node:url";
const [rootArg,outArg]=process.argv.slice(2);
if(!rootArg||!outArg)throw Error("Usage: generate_loot_art.mjs <pinned source> <Lua output>");
const root=resolve(rootArg);
const pinned="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pinned))
    throw Error("Pinned Survev source mismatch");
const load=async path=>import(pathToFileURL(resolve(root,path)).href);
const {GameObjectDefs}=await load("shared/defs/register.ts");
const {GameConfig}=await load("shared/gameConfig.ts");
const originalRoot=resolve(root,"client/public/img");
const found=new Map();
async function scan(dir){
    for(const ent of await readdir(dir,{withFileTypes:true})){
        const full=join(dir,ent.name);
        if(ent.isDirectory())await scan(full);
        else if(ent.isFile()&&/\.(svg|png|webp)$/i.test(ent.name)){
            const id=basename(ent.name,extname(ent.name));
            const rel=relative(originalRoot,full).replaceAll("\\","/")
                .replace(/\.(svg|webp)$/i,".png");
            found.set(id,[...(found.get(id)||[]),rel]);
        }
    }
}
await scan(originalRoot);
const missing=new Set();
function image(key){
    if(!key)return null;
    const id=key.replace(/\.img$/,"");
    const options=found.get(id)||[];
    if(options.length===0){missing.add(key);return null;}
    if(options.length===1)return options[0];
    const preferred=options.find(x=>x==="loot/"+id+".png");
    if(preferred)return preferred;
    throw Error("Ambiguous original loot image "+key+": "+options.join(", "));
}
const loot={},allowed=new Set(Object.keys(GameConfig.lootRadius));
for(const type of GameObjectDefs.getAllTypes()){
    const def=GameObjectDefs.typeToDef(type);
    if(!allowed.has(def.type)||!def.lootImg)continue;
    const img=def.lootImg;
    loot[type]={
        type:def.type,name:def.name??type,
        radius:GameConfig.lootRadius[def.type],
        level:def.level??null,
        sprite:img.sprite??null,asset:image(img.sprite),
        borderSprite:img.border??null,borderAsset:image(img.border),
        tint:img.tint??0xffffff,tintDark:img.tintDark??null,
        borderTint:img.borderTint??null,
        scale:img.scale??1,innerScale:img.innerScale||.8,
        rot:img.rot??0,
        ammoType:def.type==="gun"?def.ammo:null,
    };
}
const bagSizes=GameConfig.bagSizes;
function lua(v){
    if(v===null||v===undefined)return "nil";
    if(typeof v==="string")return JSON.stringify(v);
    if(typeof v==="boolean")return String(v);
    if(typeof v==="number"){
        if(!Number.isFinite(v))throw Error("Invalid nonfinite source metadata");
        return Number(v).toPrecision(17);
    }
    if(Array.isArray(v))return "{"+v.map(lua).join(",")+"}";
    return "{"+Object.entries(v).map(([k,val])=>"["+lua(keyFix(k))+"]="+lua(val)).join(",")+"}";
}
function keyFix(s){return s;}
await mkdir(dirname(resolve(outArg)),{recursive:true});
const result={loot,bagSizes,bagKeys:Object.keys(bagSizes),source:{
    revision:pinned,lootFile:"client/src/objects/loot.ts",
    configuration:"shared/gameConfig.ts"
}};
await writeFile(resolve(outArg),
    "-- GENERATED exclusively from pinned original Survev; GPL-3.0-or-later\n"+
    "-- Source images not found remain nil, never placeholder icons.\n"+
    "return "+lua(result)+"\n");
const count=Object.keys(loot).length;
console.log("Source Survev loot:",count,"definitions,",
    [...new Set(Object.values(loot).map(v=>v.asset).filter(Boolean))].length,
    "distinct real images,",missing.size,"unresolved references;");
console.log("Inventory categories:",Object.keys(bagSizes).length);
for(const required of ["9mm","762mm","bandage","healthkit","soda","painkiller","m9","ak47","backpack02","helmet02"]){
    if(!loot[required]?.asset)throw Error("Essential source loot sprite absent: "+required);
}
if(count<100||Object.keys(bagSizes).length!==25)
    throw Error("Unexpectedly incomplete source loot/inventory metadata");
