// Derive terrain EXPECTED vertices from the original TypeScript code,
// then compare each Lua-computed vertex and PRNG sample with 1e-9 tolerance.
// This does not test rivers (river/spline module still awaiting port).
import { readFile,mkdir,writeFile,mkdtemp,rm } from "node:fs/promises";
import { dirname,resolve,join } from "node:path";
import { tmpdir } from "node:os";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";
const [upstreamArg,lua="lua5.4"]=process.argv.slice(2);
if(!upstreamArg)throw Error("expected original reference checkout");
const root=resolve(upstreamArg),pin="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(pin))
    throw Error("unrecognized upstream revision");
const load=async name=>await import(pathToFileURL(resolve(root,name)).href);
const { generateTerrain,generateJaggedCirclePoints,generateJaggedAabbPoints }=
    await load("shared/utils/terrainGen.ts");
const { util }=await load("shared/utils/util.ts");
const { GameConfig }=await load("shared/gameConfig.ts");

const input=[
    {width:720,height:680,seed:123456,shoreInset:12,grassInset:9,rivers:[]},
    {width:620,height:620,seed:0,shoreInset:15,grassInset:10,rivers:[]},
    {width:810,height:640,seed:98765,shoreInset:20,grassInset:6,rivers:[]},
];
const fixture=input.map(map=>{
    const {shore,grass}=generateTerrain(map.width,map.height,map.shoreInset,
        map.grassInset,[],map.seed);
    if(shore.length!==260 || grass.length!==260)throw Error("expected 260 original outline points");
    return {map,shore,grass};
});
const seed=54321;
const patches=[
    {bound:{type:0,pos:{x:300,y:210},rad:38},roughness:.4,offsetDist:3},
    {bound:{type:1,min:{x:40,y:80},max:{x:155,y:175}},roughness:.42,offsetDist:4},
];
function roundLikeJS(value){return Math.floor(value+.5)}
const polygons=patches.map(p=>{
    const random=util.seededRand(seed);
    if(p.bound.type===0){
        const divisions=roundLikeJS((2*Math.PI*p.bound.rad*p.roughness)/Math.max(p.offsetDist,.001));
        return generateJaggedCirclePoints(p.bound.pos,p.bound.rad,divisions,
            Math.max(p.offsetDist,.001),random);
    }
    const w=p.bound.max.x-p.bound.min.x,h=p.bound.max.y-p.bound.min.y;
    return generateJaggedAabbPoints(p.bound,roundLikeJS(w*p.roughness/p.offsetDist),
        roundLikeJS(h*p.roughness/p.offsetDist),p.offsetDist,random);
});
const seeded=util.seededRand(100);
const sequence=Array.from({length:40},()=>seeded(-7.5,4.25));
const fixtureData={cases:fixture,patches,polygons,sequence,seed};
function luaTable(obj) {
    if(obj===null)return "nil";
    if(typeof obj==="number") {
        if(!Number.isFinite(obj))throw Error("NaN fixture");
        return obj.toPrecision(17);
    }
    if(typeof obj==="string")return JSON.stringify(obj);
    if(typeof obj==="boolean")return String(obj);
    if(Array.isArray(obj))return "{"+obj.map(luaTable).join(",")+"}";
    return "{"+Object.entries(obj).map(([key,value])=>"["+luaTable(key)+"]="+luaTable(value)).join(",")+"}";
}
const temp=await mkdtemp(join(tmpdir(),"survev-terrain-"));
const file=join(temp,"fixture.lua");
try{
    await writeFile(file,"return "+luaTable(fixtureData)+"\n");
    const result=spawnSync(lua,["tests/terrain_parity.lua",file],{
        encoding:"utf8",cwd:process.cwd(),maxBuffer:2*1024*1024
    });
    process.stdout.write(result.stdout);
    process.stderr.write(result.stderr);
    if(result.error)throw result.error;
    if(result.status!==0)throw Error("Terrain mismatch with Survev TypeScript");
    console.log("Original Survev shore/grass/ground-patch vertices match Lua.");
}finally {await rm(temp,{force:true,recursive:true});}
