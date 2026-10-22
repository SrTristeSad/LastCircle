/**
 * Golden inventory + nearest pickup fixtures from the pinned Survev
 * GameObjectDefs, GameConfig, and LootBarn.m_update distance expression.
 */
import {readFile,mkdtemp,writeFile,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {pathToFileURL} from "node:url";
import {tmpdir} from "node:os";
import {spawnSync} from "node:child_process";
const [refArg,engine="lua5.4"]=process.argv.slice(2);
if(!refArg)throw Error("Usage: check_loot_parity.mjs <pinned Survev root> [lua]");
const root=resolve(refArg);
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8"))
    .includes("c6185e31fe25a4a07def77a2bb25b1710bda90ac"))
    throw Error("Unverified original Survev source");
const load=async file=>import(pathToFileURL(resolve(root,file)).href);
const {GameObjectDefs}=await load("shared/defs/register.ts");
const {GameConfig}=await load("shared/gameConfig.ts");
const {v2}=await load("shared/utils/v2.ts");
const lootSource=await readFile(resolve(root,"client/src/objects/loot.ts"),"utf8");
if(!lootSource.includes("distSq < rad * rad && distSq < closestDist"))
    throw Error("Original LootBarn selection formula changed upstream");
const itemTypes=[
    "9mm","762mm","556mm","bandage","healthkit","soda","painkiller",
    "m9","ak47","backpack02","helmet02","chest02","2xscope","frag"
];
const itemData={};
for(const type of itemTypes){
    const def=GameObjectDefs.typeToDef(type);
    if(!def.lootImg)throw Error("No lootImg for original "+type);
    itemData[type]={
        kind:def.type,radius:GameConfig.lootRadius[def.type],
        scale:def.lootImg.scale,innerScale:def.lootImg.innerScale||.8,
        tint:def.lootImg.tint??0xffffff,rot:def.lootImg.rot??0,
        mirror:!!def.lootImg.mirror,
        name:def.name??type
    };
}
const bagKeys=Object.keys(GameConfig.bagSizes);
const capacities=Object.fromEntries(bagKeys.map(k=>[k,GameConfig.bagSizes[k]]));
const lootStates=[
    {id:30,type:"9mm",pos:{x:11,y:9},layer:0,count:50,ownerId:0},
    {id:31,type:"bandage",pos:{x:10,y:10},layer:0,count:2,ownerId:0},
    {id:32,type:"m9",pos:{x:12,y:10},layer:0,count:1,ownerId:3},
    {id:33,type:"soda",pos:{x:10,y:12},layer:1,count:2,ownerId:0},
];
const actorCases=[
 {pos:{x:10,y:10},layer:0,id:1},
 {pos:{x:11,y:9},layer:0,id:1},
 {pos:{x:12,y:10},layer:0,id:1},
 {pos:{x:12,y:10},layer:0,id:3},
 {pos:{x:10,y:12},layer:1,id:1},
 {pos:{x:15,y:15},layer:0,id:1},
 {pos:{x:10,y:10},layer:0,id:1,downed:true},
 {pos:{x:10,y:10},layer:0,id:1,dead:true},
];
const nearestCases=actorCases.map(actor=>{
    let closest=null,dist2=Infinity;
    if(!actor.downed&&!actor.dead){
        for(const loot of lootStates){
            if(loot.layer!==actor.layer ||
                (loot.ownerId!==0&&loot.ownerId!==actor.id))continue;
            const rad=GameConfig.lootRadius[itemData[loot.type].kind];
            const delta=v2.sub(actor.pos,loot.pos);
            const d=v2.lengthSqr(delta);
            if(d<rad*rad&&d<dist2){dist2=d;closest=loot.id;}
        }
    }
    return {actor,closest};
});
function lua(v){
    if(v==null)return "nil";
    if(typeof v==="boolean")return String(v);
    if(typeof v==="string")return JSON.stringify(v);
    if(typeof v==="number"){
        if(!Number.isFinite(v))throw Error("bad TS numeric value");
        return v.toPrecision(17);
    }
    if(Array.isArray(v))return "{"+v.map(lua).join(",")+"}";
    return "{"+Object.entries(v).map(([key,val])=>"["+lua(key)+"]="+lua(val)).join(",")+"}";
}
const tmp=await mkdtemp(join(tmpdir(),"survev-loot-"));
try{
    const file=join(tmp,"loot.lua");
    await writeFile(file,"return "+lua({itemData,bagKeys,capacities,
        lootStates,nearestCases})+"\n");
    const r=spawnSync(engine,["tests/loot_parity.lua",file],{
        cwd:process.cwd(),encoding:"utf8",maxBuffer:2e6});
    process.stdout.write(r.stdout);process.stderr.write(r.stderr);
    if(r.error)throw r.error;
    if(r.status!==0)throw Error("Original Survev loot source parity mismatch");
}finally{await rm(tmp,{recursive:true,force:true});}
