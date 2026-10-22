/**
 * Independent source TypeScript geometry fixtures for a subset of the
 * Survev Player equipped sprites. Coordinates originate in original PIXI
 * container transformations, v2.ts, Camera.ts and GameObjectDefs.
 */
import {readFile,writeFile,mkdtemp,rm} from "node:fs/promises";
import {resolve,join} from "node:path";
import {tmpdir} from "node:os";
import {pathToFileURL} from "node:url";
import {spawnSync} from "node:child_process";
const [arg,engine="lua5.4"]=process.argv.slice(2);
if(!arg)throw Error("Pinned Survev reference required");
const root=resolve(arg);
if(!(await readFile(resolve(root,"../ORIGEM.txt"),"utf8"))
    .includes("c6185e31fe25a4a07def77a2bb25b1710bda90ac"))
    throw Error("invalid Survev source revision");
const load=async rel=>import(pathToFileURL(resolve(root,rel)).href);
const {GameObjectDefs}=await load("shared/defs/register.ts");
const {IdlePoses,Bones}=await load("client/src/animData.ts");
const {Camera}=await load("client/src/camera.ts");
const {GameConfig}=await load("shared/gameConfig.ts");
const {v2}=await load("shared/utils/v2.ts");
const camera=new Camera();
camera.m_pos={x:320,y:330};
camera.m_screenWidth=960;camera.m_screenHeight=640;
const sample=[
  {__id:1,pos:{x:320,y:330},dir:{x:1,y:0},scale:1,outfit:"outfitBase",activeWeapon:"m9",backpack:"backpack02",helmet:"helmet02",chest:"chest02"},
  {__id:2,pos:{x:324,y:334},dir:{x:0,y:1},scale:1.2,outfit:"outfitDemo",activeWeapon:"m9_dual",backpack:"backpack03",helmet:"helmet01",chest:"chest03"},
  {__id:3,pos:{x:315,y:341},dir:{x:-1,y:0},scale:.7,outfit:"outfitBase",activeWeapon:"ak47",backpack:"",helmet:"",chest:""},
  {__id:4,pos:{x:320,y:330},dir:{x:1,y:0},scale:1,outfit:"outfitMedic",activeWeapon:"pan",backpack:"backpack01",helmet:"helmet03",chest:"chest02"},
];
const cases=[];
for(const player of sample){
  const equip=GameObjectDefs.typeToDef(player.activeWeapon);
  const zoom=camera.m_pixels(1);
  const t=zoom*player.scale/GameConfig.player.radius;
  const rotation=-Math.atan2(player.dir.y,player.dir.x);
  const center=camera.m_pointToScreen(player.pos);
  const expected={};
  const offset=p=>v2.add(center,v2.rotate(v2.mul(p,t),rotation));
  const put=(name,point,rot,sx,sy,ax=.5,ay=.5)=>
    expected[name]={x:point.x,y:point.y,rotation:rot,
      scaleX:sx,scaleY:sy,anchorX:ax,anchorY:ay};
  const outfit=GameObjectDefs.typeToDef(player.outfit,"outfit");
  if(player.backpack){
    const bag=GameObjectDefs.typeToDef(player.backpack,"backpack");
    const bagOff=[10.25,11.5,12.75][Math.min(bag.level-1,2)];
    const sc=t*(.4+bag.level*.03)*.5;
    put("backpack",offset({x:-bagOff,y:0}),rotation,sc,sc);
  }
  if(player.chest){
    const sc=t*.25;
    put("chest",center,rotation,sc,sc);
  }
  if(player.helmet){
    const skin=GameObjectDefs.typeToDef(player.helmet,"helmet").skinImg;
    const sc=t*(skin.spriteScale||.15);
    put("helmet",offset({x:-3.33,y:0}),rotation,sc,sc);
  }
  const poseName=equip.type==="melee"
      ?(equip.anim?.idlePose||"fists")
      :(equip.anim?.idlePose|| (equip.pistol?(equip.isDual?"dualPistol":"pistol"):
        equip.isBullpup?"bullpup":equip.isLauncher?"launcher":
        equip.isMinigun?"minigun":equip.isDual?"dualRifle":"rifle"));
  const bones=IdlePoses[poseName];
  function hand(bone,added={x:0,y:0}){
    const p=bones[bone];
    const combined=v2.add(v2.add(p.pos,added),v2.rotate(p.pivot,p.rot));
    const rotated=v2.rotate(v2.mul(combined,t),rotation);
    return {point:v2.add(center,rotated),angle:rotation+p.rot};
  }
  if(equip.type==="gun"){
    const img=equip.worldImg;
    for(const side of equip.isDual?["L","R"]:["R"]){
        const delta=side==="L"&&img.leftHandOffset?img.leftHandOffset:{x:0,y:0};
        const h=hand(side==="L"?Bones.HandL:Bones.HandR,delta);
        const gunOff=equip.isDual?{x:-5.95,y:0}:{x:-4.25,y:-1.75};
        const g=v2.add(gunOff,img.gunOffset||{x:0,y:0});
        const point=v2.add(h.point,v2.rotate(v2.mul(g,t),h.angle));
        put("gun"+side,point,h.angle+Math.PI*.5,
          zoom*img.scale.x*.5,zoom*img.scale.y*.5,.5,1);
        if(img.magImg){
            const magPos=v2.add(point,
                v2.rotate(v2.mul(img.magImg.pos,zoom),h.angle+Math.PI*.5));
            put("gunMag"+side,magPos,h.angle+Math.PI*.5,zoom*.25,zoom*.25);
        }
    }
  }
  if(equip.type==="melee"&&equip.worldImg){
    const img=equip.worldImg;
    const h=hand(Bones.HandR);
    const finalAngle=h.angle+img.rot;
    const at=v2.add(h.point,v2.rotate(v2.mul(img.pos,t),finalAngle));
    put("melee",at,finalAngle,zoom*img.scale.x,zoom*img.scale.y);
  }
  cases.push({player,expected});
}
function lua(v){
  if(v===null||v===undefined)return "nil";
  if(typeof v==="number"){
    if(!Number.isFinite(v))throw Error("bad coordinate");
    return v.toPrecision(17);
  }
  if(typeof v==="string")return JSON.stringify(v);
  if(typeof v==="boolean")return String(v);
  if(Array.isArray(v))return "{"+v.map(lua).join(",")+"}";
  return "{"+Object.entries(v).map(([k,p])=>"["+lua(k)+"]="+lua(p)).join(",")+"}";
}
const dir=await mkdtemp(join(tmpdir(),"survev-equipment-"));
try{
 const file=join(dir,"equipment.lua");
 await writeFile(file,"return "+lua({cases})+"\n");
 const r=spawnSync(engine,["tests/equipment_parity.lua",file],{
    cwd:process.cwd(),encoding:"utf8",maxBuffer:2000000
 });
 process.stdout.write(r.stdout);
 process.stderr.write(r.stderr);
 if(r.error)throw r.error;
 if(r.status!==0)throw Error("Survev source equipment coordinates differ");
}finally{await rm(dir,{recursive:true,force:true});}
