/**
 * Source-driven equipment art metadata. All values come from the PINNED
 * Survev GameObjectDefs and client/public/img, NEVER from guessed names.
 * Output consumed by Lua/LÖVE visual rendering, not fake game logic.
 */
import {readFile,readdir,writeFile,mkdir} from "node:fs/promises";
import {resolve,join,dirname,relative,extname,basename} from "node:path";
import {pathToFileURL} from "node:url";
const [refArg,outArg]=process.argv.slice(2);
if(!refArg||!outArg) throw Error("Usage: generate_equipment_art.mjs <pinned checkout> <output>");
const root=resolve(refArg);
const pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pin))
    throw Error("Source revision does not match pinned official Survev");
const {GameObjectDefs}=await import(pathToFileURL(resolve(root,"shared/defs/register.ts")).href);
const imageRoot=resolve(root,"client/public/img");
const filenames=new Map();
async function walk(folder){
    for(const entry of await readdir(folder,{withFileTypes:true})){
        const full=join(folder,entry.name);
        if(entry.isDirectory()) await walk(full);
        else if(entry.isFile()&&/\.(svg|png|webp)$/i.test(entry.name)){
            const id=basename(entry.name,extname(entry.name));
            const path=relative(imageRoot,full).replaceAll("\\","/")
                .replace(/\.(svg|webp)$/i,".png");
            filenames.set(id,[...(filenames.get(id)||[]),path]);
        }
    }
}
await walk(imageRoot);
const missing=new Set();
function asset(sprite){
    if(!sprite||sprite==="none")return null;
    const id=sprite.replace(/\.img$/,"");
    const paths=filenames.get(id)||[];
    if(paths.length===0){missing.add(sprite);return null;}
    if(paths.length===1)return paths[0];
    for(const prefix of ["weapons/","player/","loot/","map/"]){
        const picked=paths.find(p=>p===prefix+id+".png");
        if(picked)return picked;
    }
    throw Error("Ambiguous source sprite: "+sprite+" -> "+paths);
}
const weapons={},gear={},types={};
let worldCount=0,missingWorld=0;
for(const key of GameObjectDefs.getAllTypes()){
    const def=GameObjectDefs.typeToDef(key);
    if(def.type==="gun"||def.type==="melee"){
        const world=def.worldImg;
        const sprite=world?.sprite??null;
        const file=asset(sprite);
        if(world){if(file)worldCount++;else missingWorld++;}
        weapons[key]={
            type:def.type,name:def.name??key,
            idlePose:def.anim?.idlePose??null,
            isDual:!!def.isDual,
            world:world?{
                sprite,asset:file,
                tint:world.tint??0xffffff,scale:world.scale??null,
                pos:world.pos??null,rot:world.rot??0,
                leftHandOntop:!!world.leftHandOntop,
                renderOnHand:!!world.renderOnHand,
                recoil:world.recoil??0,
                gunOffset:world.gunOffset??null,
                leftHandOffset:world.leftHandOffset??null,
                handsBelow:!!world.handsBelow,
                mag:world.magImg?{
                    sprite:world.magImg.sprite,
                    asset:asset(world.magImg.sprite),
                    pos:world.magImg.pos,top:!!world.magImg.top
                }:null
            }:null,
        };
    }
    if(def.type==="helmet"||def.type==="chest"||def.type==="backpack"){
        const skin=def.skinImg??null;
        const rawSprite=skin?.baseSprite??null;
        gear[key]={
            type:def.type,name:def.name??key,level:def.level??0,
            skin:skin?{
                sprite:rawSprite,
                asset:asset(rawSprite),
                baseTint:skin.baseTint??0xffffff,
                spriteScale:skin.spriteScale??null
            }:null
        };
    }
}
function lua(v){
 if(v===null||v===undefined)return "nil";
 if(typeof v==="string")return JSON.stringify(v);
 if(typeof v==="number"){
   if(!Number.isFinite(v))throw Error("Non-finite original metadata");
   return String(v);
 }
 if(typeof v==="boolean")return String(v);
 if(Array.isArray(v))return "{"+v.map(lua).join(",")+"}";
 return "{"+Object.entries(v).map(([k,val])=>"["+lua(k)+"]="+lua(val)).join(",")+"}";
}
const result={weapons,gear,source={revision:pin}};
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),
    "-- Generated from ORIGINAL Survev GameObjectDefs (GPL-3.0-or-later)\n"+
    "-- Only original source artwork paths; nil means asset unavailable.\n"+
    "return "+lua(result)+"\n");
console.log("Original Survev equipment:",Object.keys(weapons).length,
  "weapons,",Object.keys(gear).length,"gear,",worldCount,"world images",
  missingWorld,"missing weapon images",missing.size,"unique missing sprites");
if(Object.keys(weapons).length<40||Object.keys(gear).length<8)
    throw Error("Incomplete equipment definitions");
for(const key of ["fists","pan","m9","mp5","ak47","chest01","helmet01"]){
    if(key==="chest01"||key==="helmet01"){
        if(!gear[key]?.skin?.asset)throw Error("Missing mandatory gear "+key);
    }else if(!weapons[key])throw Error("Missing source weapon "+key);
}
