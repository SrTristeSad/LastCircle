/**
 * Execute the original Survev updateMsg.ts and objectSerializeFns.ts (pinned),
 * compare a feature-complete Update frame against the Lua port byte-for-byte.
 * No invented protocol constants; only deterministic test fixture values.
 */
import { readFile, writeFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";

const upstream=resolve(process.argv[2] || "");
const interpreter=process.argv[3] || "lua5.4";
const pinned="c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if (!(await readFile(resolve(upstream,"../ORIGEM.txt"),"utf8")).includes(pinned)) {
    throw Error("Survev revision mismatch");
}
const load=async path=>await import(pathToFileURL(resolve(upstream,path)).href);
const { GameConfig }=await load("shared/gameConfig.ts");
const { GameObjectDefs,MapObjectDefs }=await load("shared/defs/register.ts");
const { ObjectSerializeFns,ObjectType }=await load("shared/net/objectSerializeFns.ts");
const { UpdateMsg }=await load("shared/net/updateMsg.ts");
const { MsgStream,BitStream,MsgType }=await load("shared/net/net.ts");

const mapType=MapObjectDefs.getAllTypes()[0];
const fixtures=[
    {__type:ObjectType.Player,__id:10,
      pos:{x:120,y:130},dir:{x:0,y:1},
      outfit:"outfitBase",backpack:"",helmet:"",chest:"",activeWeapon:"",
      layer:1,dead:false,downed:true,animType:2,animSeq:3,
      actionType:1,actionSeq:4,wearingPan:true,healEffect:false,
      lastStandEffect:true,frozen:true,frozenOri:2,frozenType:"bandage",
      hasteType:1,hasteSeq:2,actionItem:"bandage",scale:1.25,
      role:"bandage",perks:[{type:"bandage",droppable:true}]},
    {__type:ObjectType.Obstacle,__id:11,pos:{x:220,y:230},ori:2,scale:1.25,
      healthT:.8,type:mapType,layer:2,dead:false,isDoor:true,
      door:{open:true,canUse:false,locked:true,seq:11},
      isButton:true,button:{onOff:true,canUse:true,seq:29},
      isPuzzlePiece:true,parentBuildingId:32,isSkin:true,skinPlayerId:10},
    {__type:ObjectType.Loot,__id:12,pos:{x:310,y:315},type:"bandage",
      count:7,layer:1,isOld:true,isPreloadedGun:false,ownerId:10},
    {__type:ObjectType.LootSpawner,__id:13,pos:{x:350,y:360},
      type:mapType,layer:2},
    {__type:ObjectType.DeadBody,__id:14,pos:{x:400,y:405},layer:1,playerId:10},
    {__type:ObjectType.Building,__id:15,pos:{x:455,y:450},type:mapType,
      ori:1,layer:2,ceilingDead:false,occupied:true,
      ceilingDamaged:true,hasPuzzle:true,puzzle:{solved:true,errSeq:13}},
    {__type:ObjectType.Structure,__id:16,pos:{x:500,y:505},type:mapType,
      ori:3,interiorSoundEnabled:true,interiorSoundAlt:false,
      layerObjIds:[100,101]},
    {__type:ObjectType.Decal,__id:17,pos:{x:550,y:550},scale:1.5,type:mapType,
      ori:2,layer:1,goreKills:9},
    {__type:ObjectType.Projectile,__id:18,pos:{x:600,y:610},posZ:2.5,
      dir:{x:0,y:1},type:"bandage",layer:1},
    {__type:ObjectType.Smoke,__id:19,pos:{x:640,y:650},rad:4.5,
      layer:1,interior:3},
    {__type:ObjectType.Airdrop,__id:20,pos:{x:690,y:700},fallT:.75,landed:true},
];
function encodedObject(obj) {
    const funcs=ObjectSerializeFns[obj.__type];
    if (!funcs) throw Error("unknown original obj "+obj.__type);
    const part=new BitStream(new ArrayBuffer(256));
    part.writeUint8(obj.__type);
    part.writeUint16(obj.__id);
    funcs.serializePart(part,obj);
    part.writeAlignToNextByte();
    const full=new BitStream(new ArrayBuffer(256));
    funcs.serializeFull(full,obj);
    full.writeAlignToNextByte();
    return {...obj,partialStream:part,fullStream:full};
}
const msg=new UpdateMsg();
msg.delObjIds=[27,28];
msg.fullObjects=fixtures.map(encodedObject);
msg.partObjects=fixtures.slice(0,4).map(encodedObject);
msg.activePlayerId=10;
msg.activePlayerIdDirty=true;
const inventory=Object.fromEntries(Object.keys(GameConfig.bagSizes).map(k=>[k,0]));
inventory["9mm"]=87;
inventory.bandage=5;
inventory["4xscope"]=1;
msg.activePlayerData={
    healthDirty:true,health:73,
    boostDirty:true,boost:28,
    zoomDirty:true,zoom:40,
    actionDirty:true,action:{time:1.25,duration:3.5,targetId:14},
    inventoryDirty:true,scope:"4xscope",inventory,
    weapsDirty:true,curWeapIdx:1,
    weapons:[
        {type:"bandage",ammo:9},{type:"",ammo:0},
        {type:"bandage",ammo:1},{type:"",ammo:0}
    ],
    spectatorCountDirty:true,spectatorCount:2,
};
msg.gasDirty=true;
msg.gasData={mode:2,duration:38.5,posOld:{x:400,y:400},
    posNew:{x:350,y:375},radOld:650,radNew:400};
msg.gasTDirty=true;
msg.gasT=.45;
msg.playerInfos=[{playerId:10,teamId:1,groupId:2,name:"Player One",
    loadout:{heal:"bandage",boost:""}}];
msg.deletedPlayerIds=[72,73];
msg.playerStatusDirty=true;
msg.playerStatus=[
    {hasData:true,pos:{x:120,y:130},visible:true,dead:false,downed:false,role:"bandage"},
    {hasData:false}
];
msg.groupStatusDirty=true;
msg.groupStatus=[
    {health:90,disconnected:false},
    {health:25,disconnected:true}
];
msg.bullets=[{
    playerId:10,startPos:{x:100,y:110},dir:{x:1,y:0},
    bulletType:"bullet_mp5",layer:1,varianceT:.6,distAdjIdx:7,
    clipDistance:true,distance:150,shotFx:true,shotSourceType:"bandage",
    shotOffhand:true,lastShot:false,reflectCount:2,reflectObjId:11,
    hasModifier:true,speedMult:1.25,distanceMult:.85,hasSpecialFx:true,
    shotAlt:true,splinter:false,trailSaturated:true,apRounds:false,
    highVelocity:true,combatStims:false,trailSmall:true,trailThick:false
}];
msg.explosions=[{pos:{x:200,y:220},type:"bandage",layer:2}];
msg.emotes=[{playerId:10,type:"emote_happyface",itemType:"bandage",
    isPing:true,pos:{x:123,y:124}}];
msg.planes=[{id:1,pos:{x:250,y:260},planeDir:{x:0,y:1},
    actionComplete:true,action:1}];
msg.airstrikeZones=[{pos:{x:330,y:340},rad:40,duration:12}];
msg.mapIndicators=[{id:3,dead:false,equipped:true,
    type:"bandage",pos:{x:440,y:450}}];
msg.killLeaderDirty=true;
msg.killLeaderId=10;
msg.killLeaderKills=6;
msg.ack=91;
const packet=new MsgStream(new ArrayBuffer(16384));
packet.serializeMsg(MsgType.Update,msg);
const gold=Buffer.from(packet.getBuffer()).toString("hex");
const parsed=new MsgStream(packet.getBuffer());
if(parsed.deserializeMsgType()!==MsgType.Update)throw Error("upstream framing failed");
const decoded=new UpdateMsg();
decoded.deserialize(parsed.getStream(),{m_getTypeById() {return ObjectType.Invalid;}});
if(decoded.fullObjects.length!==11 || decoded.partObjects.length!==4
    || decoded.activePlayerData.inventory["9mm"]!==87
    || decoded.bullets.length!==1 || decoded.gasData.duration!==38.5
    || decoded.ack!==91) throw Error("original Survev self-decoding failed");

console.log("Upstream UpdateMsg full feature fixture:",gold.length/2,"bytes");
function toLua(value) {
    if (value===null || value===undefined) return "nil";
    if (typeof value==="boolean" || typeof value==="number") return String(value);
    if (typeof value==="string") {
        if (!/^[\x00-\x7e]*$/.test(value)) throw Error("fixture must be ASCII");
        return JSON.stringify(value);
    }
    if (Array.isArray(value)) return "{"+value.map(toLua).join(",")+"}";
    if (typeof value==="object") {
        return "{"+Object.entries(value).map(([key,v])=>"["+toLua(key)+"]="+toLua(v)).join(",")+"}";
    }
    throw Error("unserializable fixture type "+typeof value);
}
const fixture={...msg,fullObjects:fixtures,partObjects:fixtures.slice(0,4)};
const tempDir=await mkdtemp(join(tmpdir(),"survev-update-"));
const fixturePath=join(tempDir,"update_fixture.lua");
await writeFile(fixturePath,"return "+toLua(JSON.parse(JSON.stringify(fixture)))+"\n","utf8");

const result=spawnSync(interpreter,["tests/update_parity.lua",gold,fixturePath],{
    encoding:"utf8",cwd:process.cwd(),maxBuffer:4*1024*1024
});
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
if(result.error) throw result.error;
await rm(tempDir,{recursive:true,force:true});
if(result.status!==0) throw Error("Lua UpdateMsg parity failed (exit "+result.status+")");
