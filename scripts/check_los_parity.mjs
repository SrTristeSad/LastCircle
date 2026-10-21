/**
 * Original Survev wall-aware roof LOS parity.
 * Expected math comes ONLY from pinned shared/utils/coldet.ts,
 * collider.ts, collisionHelpers.ts, and MapObjectDefs.
 */
import {readFile,mkdtemp,writeFile,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [rootArg,engine="lua5.4"]=process.argv.slice(2);
if(!rootArg)throw Error("Survev original reference checkout required");
const root=resolve(rootArg);
const revision="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8")).includes(revision))
  throw Error("incorrect source reference");
const load=async p=>await import(pathToFileURL(resolve(root,p)).href);
const {MapObjectDefs}=await load("shared/defs/register.ts");
const {collider}=await load("shared/utils/collider.ts");
const {collisionHelpers}=await load("shared/utils/collisionHelpers.ts");
const {math}=await load("shared/utils/math.ts");
const {v2}=await load("shared/utils/v2.ts");

const zoomBoxes=[
  {type:1,min:{x:-4,y:-4},max:{x:4,y:4}},
  {type:0,pos:{x:0,y:0},rad:4},
  {type:1,min:{x:10,y:5},max:{x:19,y:15}},
];
const wallTypes=MapObjectDefs.getAllTypes().filter(k=>{
  const d=MapObjectDefs.typeToDef(k);
  return d.type==="obstacle"&&d.collidable&&d.isWall&&!d.isWindow;
});
if(!wallTypes.length)throw Error("Original source contains no wall definitions");
const wallType=wallTypes[0];
function O(type,x,y,ori=0,extra={}){
  return {__type:2,__id:200+Math.round(x*19+y*11)%300,
    type,pos:{x,y},ori,scale:1,layer:0,dead:false,isSkin:false,...extra};
}
const groups=[
  [],
  [O("house_door_01",6,-2)],
  [O("house_door_01",6,-2,0,{dead:true})],
  [O("house_door_01",6,-2,0,{isSkin:true})],
  [O("house_door_01",6,-2,0,{layer:1})],
  [O("house_door_01",6,-2,0,{layer:2})],
  [O(wallType,6,0)],
  [O(wallType,6,0,0,{dead:true})],
  [O(wallType,6,0,0,{layer:1})],
  [O(wallType,6,0,1)],
  [O(wallType,6,0,0,{scale:1.5})],
  [O("house_door_01",6,-2), O(wallType,7,0)],
];
const positions=[
  {x:0,y:0},{x:4.25,y:0},{x:6,y:0},{x:7,y:0},{x:8,y:0},
  {x:9,y:2},{x:9,y:5},{x:12,y:0},{x:9,y:-6},{x:0,y:12},
  {x:22,y:10},{x:10,y:6},{x:-8,y:0},{x:4,y:4},{x:4,y:-4}
];
function makeSourceObstacle(o){
  const def=MapObjectDefs.typeToDef(o.type,"obstacle");
  return {__id:o.__id,active:true,dead:o.dead,collidable:def.collidable&&!o.isSkin,
    isWindow:!!def.isWindow,height:def.height,layer:o.layer,
    collider:collider.transform(def.collision,o.pos,math.oriToRad(o.ori),o.scale)};
}
const fixtures=[];
for(const box of zoomBoxes)for(const pos of positions)for(const group of groups){
  const scanDist=5.5,scanWidth=5.5,layer=0;
  const obstacles=group.map(makeSourceObstacle);
  const expected=collisionHelpers.scanCollider(box,obstacles,pos,layer,0,
    scanWidth,scanDist,5);
  fixtures.push({box,pos,obstacles:group,expected});
}
for(const layer of [1,2,3]){
    for(const pos of [{x:8,y:0},{x:6,y:2},{x:9,y:5}]){
       const group=[O("house_door_01",6,-2),O(wallType,8,1)];
       const expected=collisionHelpers.scanCollider(zoomBoxes[0],
          group.map(makeSourceObstacle),pos,layer,0,5.5,5.5,5);
       fixtures.push({box:zoomBoxes[0],pos,obstacles:group,layer,expected});
    }
}
// Independently verify source collider primitives used by scan rays.
const segmentCases=[];
for(const col of zoomBoxes){
 for(const [p,q] of [
  [{x:9,y:0},{x:0,y:0}],
  [{x:0,y:9},{x:0,y:-9}],
  [{x:-8,y:3},{x:8,y:3}],
  [{x:0,y:0},{x:0,y:0}],
  [{x:12,y:12},{x:18,y:12}],
 ]) {
    const hit=collider.intersectSegment(col,p,q);
    segmentCases.push({col,p,q,expected:hit?hit.point:null});
 }
}
const circleCases=[];
for(const col of zoomBoxes)for(const pos of positions){
    const out=collider.intersectCircle(col,pos,5.5);
    circleCases.push({col,pos,expected:out?{dir:out.dir,pen:out.pen}:null});
}
const out={wallType,fixtures,segmentCases,circleCases};
function lua(x) {
  if(x==null)return "nil";
  if(typeof x==="string")return JSON.stringify(x);
  if(typeof x==="number"){
    if(!Number.isFinite(x))throw Error("invalid numeric");
    return x.toPrecision(17);
  }
  if(typeof x==="boolean")return String(x);
  if(Array.isArray(x))return "{"+x.map(lua).join(",")+"}";
  return "{"+Object.entries(x).map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
}
const dir=await mkdtemp(join(tmpdir(),"survev-los-"));
try{
 const filename=join(dir,"los.lua");
 await writeFile(filename,"return "+lua(out)+"\n");
 const result=spawnSync(engine,["tests/los_parity.lua",filename],{
    cwd:process.cwd(),encoding:"utf8",maxBuffer:3*1024*1024
 });
 process.stdout.write(result.stdout);process.stderr.write(result.stderr);
 if(result.error)throw result.error;
 if(result.status!==0)throw Error("Survev source and Lua wall LOS differ");
} finally {await rm(dir,{recursive:true,force:true});}
