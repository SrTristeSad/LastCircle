/**
 * Export original Survev player outfit sprites and idle poses for Lua.
 * Values are read directly from the pinned upstream GameObjectDefs/animData
 * instead of approximating character colors, hands or sizes.
 */
import {readFile,readdir,mkdir,writeFile} from "node:fs/promises";
import {resolve,join,relative,extname,basename,dirname} from "node:path";
import {pathToFileURL} from "node:url";
const [referenceArg,outArg]=process.argv.slice(2);
if(!referenceArg||!outArg) throw Error("Usage: generate_player_art.mjs <upstream> <Lua file>");
const root=resolve(referenceArg);
const pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pin))
    throw Error("Unverified upstream Survev commit");
const importSource=async relativePath=>
    import(pathToFileURL(resolve(root,relativePath)).href);
const {GameObjectDefs}=await importSource("shared/defs/register.ts");
const {IdlePoses,Bones,Animations}=await importSource("client/src/animData.ts");
const imageRoot=resolve(root,"client/public/img");
const filenames=new Map();
async function walk(path){
    for(const f of await readdir(path,{withFileTypes:true})){
        const full=join(path,f.name);
        if(f.isDirectory())await walk(full);
        else if(f.isFile()&&/\.(svg|png|webp)$/i.test(f.name)){
            const k=basename(f.name,extname(f.name));
            const p=relative(imageRoot,full).replaceAll("\\","/")
                .replace(/\.(svg|webp)$/i,".png");
            filenames.set(k,[...(filenames.get(k)||[]),p]);
        }
    }
}
await walk(imageRoot);
function sprite(key){
    if(!key)return null;
    const name=key.replace(/\.img$/,"");
    const candidates=filenames.get(name)||[];
    if(!candidates.length)return null;
    if(candidates.length===1)return candidates[0];
    const own=candidates.find(x=>x==="player/"+name+".png");
    if(own)return own;
    throw Error("Ambiguous original image "+key+": "+candidates.join(", "));
}
const outfits={};
for(const key of GameObjectDefs.getAllTypes()){
    const def=GameObjectDefs.typeToDef(key);
    if(def.type!=="outfit")continue;
    const img=def.skinImg;
    const hands=typeof img.handSprite==="string"
        ?{left:img.handSprite,right:img.handSprite}:img.handSprite;
    const info={
        ghillie:!!def.ghillie,
        baseTint:img.baseTint,handTint:img.handTint,footTint:img.footTint,
        baseSprite:img.baseSprite,handLSprite:hands.left,handRSprite:hands.right,
        footSprite:img.footSprite,
        backpackSprite:img.backpackSprite,
        backpackTint:img.backpackTint,
        baseAsset:sprite(img.baseSprite),
        handLAsset:sprite(hands.left),handRAsset:sprite(hands.right),
        footAsset:sprite(img.footSprite),
        backpackAsset:sprite(img.backpackSprite),
    };
    if(!info.baseAsset||!info.handLAsset||!info.handRAsset||!info.footAsset||!info.backpackAsset)
        throw Error("Missing upstream artwork for "+key+" "+JSON.stringify(info));
    outfits[key]=info;
}
const poses={};
for(const [key,data] of Object.entries(IdlePoses)){
    const pose={};
    for(const [name,id] of Object.entries({HandL:Bones.HandL,HandR:Bones.HandR,
        FootL:Bones.FootL,FootR:Bones.FootR})){
        if(data[id])pose[name]={
            pivot:data[id].pivot,pos:data[id].pos,rot:data[id].rot
        };
    }
    poses[key]=pose;
}
function lua(v){
    if(v===null||v===undefined)return "nil";
    if(typeof v==="string")return JSON.stringify(v);
    if(typeof v==="number"){
        if(!Number.isFinite(v))throw Error("Invalid source number");
        return Number(v).toString();
    }
    if(typeof v==="boolean")return String(v);
    if(Array.isArray(v))return "{"+v.map(lua).join(",")+"}";
    if(typeof v==="object")return "{"+Object.entries(v)
        .map(([key,val])=>"["+lua(key)+"]="+lua(val)).join(",")+"}";
    throw Error("Invalid metadata "+typeof v);
}
const punching=Animations.fists.keyframes.map(frame=>({
    time:frame.time,
    handR:{
        pivot:frame.bones[Bones.HandR].pivot,
        pos:frame.bones[Bones.HandR].pos,
        rot:frame.bones[Bones.HandR].rot,
    },
}));
const output={
    animations:{fists:punching},
    sprites:{bodyScale:0.25,handScale:0.175,footScale:0.45},
    outfits,idlePoses:poses,
    source:{revision:pin,poseFile:"client/src/animData.ts",
        outfitFile:"shared/defs/gameObjects/outfitDefs.ts"}
};
await mkdir(dirname(resolve(outArg)),{recursive:true});
await writeFile(resolve(outArg),
    "-- Generated from pinned ORIGINAL Survev outfits and idle poses.\n"+
    "-- GPL-3.0-or-later; original asset paths verified (no substituted art).\n"+
    "return "+lua(output)+"\n");
console.log("Upstream Survev player metadata:",Object.keys(outfits).length,
    "outfits,",Object.keys(poses).length,"idle poses,",punching.length,"fist animation keyframes");
if(Object.keys(outfits).length<10||Object.keys(poses).length<10)
    throw Error("Incomplete original player metadata");
