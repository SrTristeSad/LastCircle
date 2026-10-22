/**
 * Golden-screen-space reference for source Survev basic Player body/hand pass.
 * Reads the original outfitDefs, animData.ts, camera.ts and v2.ts at the
 * pinned commit; invokes the actual Lua renderer for numerical comparison.
 */
import {readFile,mkdtemp,writeFile,rm} from "node:fs/promises";
import {join,resolve} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [refArg,engine="lua5.4"]=process.argv.slice(2);
if(!refArg)throw Error("Usage: check_player_parity.mjs <survev root> [lua]");
const root=resolve(refArg);
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8"))
    .includes("c6185e31fe25a4a07def77a2bb25b1710bda90ac"))
    throw Error("unverified original Survev revision");
const importFile=async name=>import(pathToFileURL(resolve(root,name)).href);
const {GameObjectDefs}=await importFile("shared/defs/register.ts");
const {IdlePoses,Bones,Animations}=await importFile("client/src/animData.ts");
const {Camera}=await importFile("client/src/camera.ts");
const {v2}=await importFile("shared/utils/v2.ts");
const config=await importFile("shared/gameConfig.ts");
const camera=new Camera();
camera.m_screenWidth=1280;camera.m_screenHeight=720;
camera.m_pos={x:320,y:333};
const cases=[];
for(const [outfit,dir,position,scale,downed] of [
 ["outfitBase",{x:1,y:0},{x:320,y:333},1,false],
 ["outfitBase",{x:0,y:1},{x:327,y:329},1,false],
 ["outfitDemo",{x:-1,y:0},{x:312,y:344},.8,false],
 ["outfitMedic",{x:0,y:-1},{x:333,y:329},1.2,false],
 ["outfitBase",{x:1,y:1},{x:320,y:333},1,true],
 ["outfitScout",{x:1,y:-1},{x:314,y:345},.5,false],
]){
 const def=GameObjectDefs.typeToDef(outfit,"outfit");
 const raw=def.skinImg;
 const hand=typeof raw.handSprite==="string"
    ?{left:raw.handSprite,right:raw.handSprite}:raw.handSprite;
 const world={pos:position,dir,outfit,scale,downed,__id:12,dead:false};
 const theta=-Math.atan2(dir.y,dir.x);
 const center=camera.m_pointToScreen(position);
 const outer=camera.m_pixels(1)*scale/config.GameConfig.player.radius;
 const pose=IdlePoses[downed?"downed":"fists"];
 const expected=[];
 function append(name,sprite,tint,localScale,bone,extra=0) {
    let x=center.x,y=center.y,angle=theta;
    if(bone){
      const off=v2.add(bone.pos,v2.rotate(bone.pivot,bone.rot));
      const rot=v2.rotate(v2.mul(off,outer),theta);
      x+=rot.x;y+=rot.y;angle+=bone.rot;
    }
    expected.push({
      name,asset:"player/"+sprite.replace(/\.img$/,"")+".png",
      x,y,rotation:angle+extra,scale:outer*localScale,tint
    });
 }
 if(downed){
   append("footL",raw.footSprite,raw.footTint,.45,pose[Bones.FootL],Math.PI/2);
   append("footR",raw.footSprite,raw.footTint,.45,pose[Bones.FootR],Math.PI/2);
 }
 append("body",raw.baseSprite,raw.baseTint,.25);
 append("handL",hand.left,raw.handTint,.175,pose[Bones.HandL]);
 append("handR",hand.right,raw.handTint,.175,pose[Bones.HandR]);
 cases.push({world,expected});
}
// Compare the actual Survev animations.fists keyframe positions (left click
// is a VISUAL test only; no damage is simulated by LastCircle).
for(const time of [0,.03,.1,.175,.24]){
    const base=cases[0];
    const frames=Animations.fists.keyframes;
    let a=frames[0],b=frames[1];
    for(let i=1;i<frames.length;i++){
        if(time<=frames[i].time){a=frames[i-1];b=frames[i];break;}
    }
    const weight=(time-a.time)/(b.time-a.time);
    const lerp=(v,w)=>v+(w-v)*weight;
    const handA=a.bones[Bones.HandR],handB=b.bones[Bones.HandR];
    const pivot={
        x:lerp(handA.pivot.x,handB.pivot.x),
        y:lerp(handA.pivot.y,handB.pivot.y)
    };
    const original=base.expected.map(e=>({...e}));
    const outer=camera.m_pixels(1);
    const center=camera.m_pointToScreen(base.world.pos);
    original[2].x=center.x+pivot.x*outer;
    original[2].y=center.y+pivot.y*outer;
    original[2].rotation=0;
    cases.push({
        world:{...base.world,offlinePreview:true,previewFistTicker:time},
        expected:original
    });
}
function lua(x){
 if(x==null)return "nil";
 if(typeof x==="number"){
   if(!Number.isFinite(x))throw Error("not a number");
   return x.toPrecision(17);
 }
 if(typeof x==="boolean")return String(x);
 if(typeof x==="string")return JSON.stringify(x);
 if(Array.isArray(x))return "{"+x.map(lua).join(",")+"}";
 return "{"+Object.entries(x).map(([k,v])=>"["+lua(k)+"]="+lua(v)).join(",")+"}";
}
const folder=await mkdtemp(join(tmpdir(),"survev-player-"));
try {
 const f=join(folder,"player.lua");
 await writeFile(f,"return "+lua({cases})+"\n");
 const r=spawnSync(engine,["tests/player_parity.lua",f],
    {cwd:process.cwd(),encoding:"utf8",maxBuffer:2e6});
 process.stdout.write(r.stdout);process.stderr.write(r.stderr);
 if(r.error)throw r.error;
 if(r.status!==0)throw Error("Lua player sizes/poses mismatch original source");
}finally{await rm(folder,{force:true,recursive:true});}
