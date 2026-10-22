/**
 * Golden HUD health/boost fixtures derived directly from PINNED Survev
 * client/src/ui/ui2.ts and shared/gameConfig.ts. No assumed colors or ranges.
 */
import {readFile,writeFile,mkdtemp,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [rootArg,engine="lua5.4"]=process.argv.slice(2);
if(!rootArg)throw Error("Pass source checkout");
const root=resolve(rootArg);
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8"))
    .includes("c6185e31fe25a4a07def77a2bb25b1710bda90ac"))
    throw Error("Incorrect upstream Survev revision");
const {GameConfig}=await import(pathToFileURL(resolve(root,"shared/gameConfig.ts")).href);
const {math}=await import(pathToFileURL(resolve(root,"shared/utils/math.ts")).href);
const ui=await readFile(resolve(root,"client/src/ui/ui2.ts"),"utf8");
const begin=ui.indexOf("const steps = [",ui.indexOf("// Health"));
const end=ui.indexOf("];",begin);
if(begin<0||end<0)throw Error("Original Survev HUD health steps not found");
const stepString=ui.slice(begin,end);
const steps=[...stepString.matchAll(/health:\s*(\d+),\s*color:\s*\[\s*(\d+),\s*(\d+),\s*(\d+)\s*\]/g)]
    .map(m=>({health:Number(m[1]),color:[Number(m[2]),Number(m[3]),Number(m[4])]}));
if(steps.length!==7)throw Error("Expected exactly 7 original gradient steps");
function sourceHealth(value,downed){
 let idx=0;
 while(steps[idx].health>Math.ceil(value) && idx<steps.length-1)idx++;
 const a=steps[Math.max(idx-1,0)],b=steps[idx];
 const t=math.delerp(value,a.health,b.health);
 const color=a.color.map((v,i)=>Math.floor(math.lerp(t,v,b.color[i])));
 if(downed)return [255,0,0];
 if(!color.every(Number.isFinite))throw Error("Undefined original health gradient at "+value);
 return color;
}
function sourceBoost(value){
 const steps=GameConfig.player.boostBreakpoints;
 const max=steps.reduce((a,b)=>a+b,0);
 let rest=value/100;
 return steps.map(step=>{
    const normalized=step/max;
    const fill=math.clamp(rest/normalized,0,1);
    rest=Math.max(rest-normalized,0);
    return fill;
 });
}
const healthCases=[0,1,2,12.25,24.99,25,25.5,35,50,60,74.9,75,75.5,80,98.5,99].flatMap(x=>
    [false,true].map(downed=>({value:x,downed,expected:sourceHealth(x,downed)})));
const boostCases=[0,1,12.5,25,37.5,50,62.5,75,87.5,100].map(x=>
    ({value:x,expected:sourceBoost(x)}));
const weaponSlotCount=GameConfig.WeaponSlot.Count;
const ammoSource=[
    GameConfig.WeaponSlot.Primary,GameConfig.WeaponSlot.Secondary,
    GameConfig.WeaponSlot.Melee,GameConfig.WeaponSlot.Throwable
];
function lua(x){
 if(x===null||x===undefined)return "nil";
 if(typeof x==="number"){
   if(!Number.isFinite(x))throw Error("NaN fixture");
   return x.toPrecision(17);
 }
 if(typeof x==="boolean")return String(x);
 if(typeof x==="string")return JSON.stringify(x);
 if(Array.isArray(x))return "{"+x.map(lua).join(",")+"}";
 return "{"+Object.entries(x).map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
}
const dir=await mkdtemp(join(tmpdir(),"survev-hud-"));
try{
 const path=join(dir,"golden.lua");
 await writeFile(path,"return "+lua({
    healthCases,boostCases,weaponSlotCount,ammoSource
 })+"\n");
 const run=spawnSync(engine,["tests/hud_parity.lua",path],{
    cwd:process.cwd(),encoding:"utf8",maxBuffer:1e6
 });
 process.stdout.write(run.stdout);process.stderr.write(run.stderr);
 if(run.error)throw run.error;
 if(run.status!==0)throw Error("Survev source HUD parity failed");
}finally{await rm(dir,{recursive:true,force:true});}
