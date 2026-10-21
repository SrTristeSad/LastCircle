/**
 * Produce door position/rotation interpolation fixtures from original
 * client/src/objects/obstacle.ts and shared/utils/math.ts.
 */
import {readFile,mkdtemp,writeFile,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [refArg,engine="lua5.4"]=process.argv.slice(2);
if(!refArg)throw Error("pinned Survev reference required");
const root=resolve(refArg);
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes("c6185e31fe25a4a07def77a2bb25b1710bda90ac"))throw Error("wrong upstream commit");
const load=async p=>await import(pathToFileURL(resolve(root,p)).href);
const {MapObjectDefs}=await load("shared/defs/register.ts");
const {v2}=await load("shared/utils/v2.ts");
const {math}=await load("shared/utils/math.ts");
const defs=MapObjectDefs.getAllTypes().map(name=>[name,MapObjectDefs.typeToDef(name)]).filter(([,d])=>d.type==="obstacle"&&d.door);
const cased=defs.find(([,d])=>d.door.casingImg);
const choice=cased ? cased[0] : "house_door_01";
const candidates=["house_door_01",choice];
const stages=[];
for(const type of candidates){
    const d=MapObjectDefs.typeToDef(type,"obstacle");
    let pos=v2.create(100,200),rot=math.oriToRad(0);
    const itinerary=[
        {x:100,y:200,ori:0,open:false,dt:0},
        {x:104,y:204,ori:1,open:true,dt:.016},
        {x:104,y:204,ori:1,open:true,dt:.05},
        {x:104,y:204,ori:1,open:true,dt:.1},
        {x:104,y:204,ori:1,open:true,dt:.24},
        {x:104,y:204,ori:1,open:true,dt:2.5},
        {x:98,y:199,ori:3,open:false,dt:.07},
        {x:98,y:199,ori:3,open:false,dt:.25},
        {x:98,y:199,ori:3,open:false,dt:2.5},
    ];
    for(let j=0;j<itinerary.length;j++){
        const frame=itinerary[j],target=v2.create(frame.x,frame.y);
        const speed=d.door.openSpeed;
        const moveDiff=v2.sub(target,pos);
        const distance=v2.length(moveDiff);
        const delta=Math.min(speed*frame.dt,distance);
        const dir=distance>.0001?v2.div(moveDiff,distance):v2.create(1,0);
        pos=v2.add(pos,v2.mul(dir,delta));
        const desired=math.oriToRad(frame.ori);
        const angle=math.angleDiff(rot,desired);
        let amount=math.sign(angle)*Math.PI*speed*frame.dt;
        if(Math.abs(angle)<Math.abs(amount))amount=angle;
        rot+=amount;
        const offset=v2.rotate(v2.create(d.door.slideOffset,0),desired+Math.PI/2);
        const closed=frame.open?v2.add(target,offset):v2.copy(target);
        const casing=d.door.casingImg;
        const casingPos=casing?v2.add(closed,v2.rotate(casing.pos||v2.create(0,0),desired+Math.PI/2)):null;
        stages.push({type,dt:frame.dt,frame:{__type:2,__id:18,type,
          pos:target,ori:frame.ori,scale:1,layer:0,dead:false,door:{open:frame.open}},
          expected:{pos,rot,casingPos}});
    }
}
function lua(x){
 if(x==null)return "nil";
 if(typeof x==="string")return JSON.stringify(x);
 if(typeof x==="boolean")return String(x);
 if(typeof x==="number"){if(!Number.isFinite(x))throw Error("invalid source number");return x.toPrecision(17)}
 if(Array.isArray(x))return "{"+x.map(lua).join(",")+"}";
 return "{"+Object.entries(x).map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
}
const dir=await mkdtemp(join(tmpdir(),"survev-door-"));
try{
 const f=join(dir,"door.lua");
 await writeFile(f,"return "+lua({hasCasing:!!cased,stages})+"\n");
 const r=spawnSync(engine,["tests/door_parity.lua",f],{encoding:"utf8",cwd:process.cwd(),maxBuffer:1e6});
 process.stdout.write(r.stdout);process.stderr.write(r.stderr);
 if(r.error)throw r.error;
 if(r.status!==0)throw Error("Source Survev door visual parity test failed");
} finally {await rm(dir,{recursive:true,force:true});}
