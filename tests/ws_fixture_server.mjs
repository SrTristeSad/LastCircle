// Loopback RFC 6455 integration server. Produces Survev packets with
// the PINNED ORIGINAL TypeScript serializers rather than invented bytes.
// No external npm or WebSocket server packages are needed.
import net from "node:net";
import crypto from "node:crypto";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
const root=resolve(process.env.SURVEV_ROOT || "_reference/reference/survev");
const load=async p=>await import(pathToFileURL(resolve(root,p)).href);
const { MsgStream,MsgType,BitStream }=await load("shared/net/net.ts");
const { JoinMsg }=await load("shared/net/joinMsg.ts");
const { InputMsg }=await load("shared/net/inputMsg.ts");
const { SpectateMsg,SpectateAction }=await load("shared/net/spectateMsg.ts");
const { DropItemMsg }=await load("shared/net/dropItemMsg.ts");
const { Input }=await load("shared/gameConfig.ts");
const { JoinedMsg }=await load("shared/net/joinedMsg.ts");
const { MapMsg }=await load("shared/net/mapMsg.ts");
const { UpdateMsg }=await load("shared/net/updateMsg.ts");
const { ObjectSerializeFns,ObjectType }=await load("shared/net/objectSerializeFns.ts");

const PORT=19998;
const GUID="258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
function serverFrame(body,opcode=2,fin=true) {
  const data=Buffer.from(body);
  const n=data.length;
  const h=n<=125?Buffer.from([(fin?128:0)+opcode,n])
      :n<=65535?Buffer.from([(fin?128:0)+opcode,126,n>>>8,n&255])
      :Buffer.from([(fin?128:0)+opcode,127,0,0,0,0,
         (n/16777216)&255,(n/65536)&255,(n/256)&255,n&255]);
  return Buffer.concat([h,data]);
}
function framedMsg(type,msg) {
  const s=new MsgStream(new ArrayBuffer(2048));
  s.serializeMsg(type,msg);
  return Buffer.from(s.getBuffer());
}
function wsHandshake(raw) {
  const request=raw.toString("latin1");
  const [,key]=request.match(/sec-websocket-key:\s*([^\r\n]+)/i)||[];
  if(!key)throw Error("Missing websocket key");
  if(!/^GET \/relay\?test=1 HTTP\/1\.1\r\n/.test(request))throw Error("Invalid websocket target");
  const accept=crypto.createHash("sha1").update(key.trim()+GUID).digest("base64");
  return "HTTP/1.1 101 Switching Protocols\r\n"+
   "Upgrade: websocket\r\nConnection: Upgrade\r\n"+
   "Sec-WebSocket-Accept: "+accept+"\r\n\r\n";
}
function decodeClient(buffer) {
  if(buffer.length<2)return null;
  let n=buffer[1]&127,offset=2;
  if((buffer[1]&128)===0)throw Error("unmasked client frame");
  if(n===126){if(buffer.length<4)return null;n=buffer.readUInt16BE(2);offset=4;}
  if(n===127){if(buffer.length<10)return null;n=Number(buffer.readBigUInt64BE(2));offset=10;}
  if(n>8*1024*1024)throw Error("huge frame");
  if(buffer.length<offset+4+n)return null;
  const mask=buffer.subarray(offset,offset+4);
  const body=Buffer.from(buffer.subarray(offset+4,offset+4+n));
  for(let i=0;i<n;i++)body[i]^=mask[i%4];
  return {frame:{opcode:buffer[0]&15,payload:body},rest:buffer.subarray(offset+4+n)};
}
function playerPayload(x,y,full=true,id=7,dead=false) {
  const d={
    __type:ObjectType.Player,__id:id,pos:{x,y},dir:{x:1,y:0},
    outfit:"outfitBase",backpack:"",helmet:"",chest:"",activeWeapon:"",
    layer:0,dead,downed:false,animType:0,animSeq:0,
    actionType:0,actionSeq:0,wearingPan:false,healEffect:false,
    lastStandEffect:false,frozen:false,hasteType:0,hasteSeq:0,
    actionItem:"",scale:1,role:"",perks:[]
  };
  const part=new BitStream(new ArrayBuffer(128));
  part.writeUint8(d.__type);
  part.writeUint16(d.__id);
  ObjectSerializeFns[ObjectType.Player].serializePart(part,d);
  part.writeAlignToNextByte();
  const fullStream=new BitStream(new ArrayBuffer(256));
  ObjectSerializeFns[ObjectType.Player].serializeFull(fullStream,d);
  fullStream.writeAlignToNextByte();
  return {...d,partialStream:part,fullStream};
}
const update=()=> {
  const u=new UpdateMsg();
  u.activePlayerIdDirty=true;
  u.activePlayerId=7;
  u.activePlayerData={
    healthDirty:true,health:80,boostDirty:false,zoomDirty:false,
    actionDirty:false,inventoryDirty:false,weapsDirty:false,
    spectatorCountDirty:false
  };
  u.ack=0;
  u.fullObjects=[playerPayload(120,140)];
  return u;
};
const listen=net.createServer(socket=>{
  let buffer=Buffer.alloc(0),upgraded=false,joinSeen=false,inputSeen=false,pongSeen=false;
  let spectatorSession=false,spectateSeen=false,spectateIndex=0;
  let combatSession=false,combatStep=0,dropSeen=false;
  socket.setNoDelay(true);
  socket.on("data",async data=>{
    try {
      buffer=Buffer.concat([buffer,data]);
      if(!upgraded) {
        const end=buffer.indexOf("\r\n\r\n");
        if(end<0)return;
        socket.write(wsHandshake(buffer.subarray(0,end+4)));
        buffer=buffer.subarray(end+4);
        upgraded=true;
      }
      for(let i=0;i<30;i++) {
        const decoded=decodeClient(buffer);
        if(!decoded)break;
        buffer=decoded.rest;
        const {opcode,payload}=decoded.frame;
        if(opcode===10){pongSeen=true;continue;}
        if(opcode===8){socket.end();return;}
        if(opcode!==2)throw Error("expected binary game frame");
        const stream=new MsgStream(payload.buffer.slice(
          payload.byteOffset,payload.byteOffset+payload.byteLength
        ));
        const type=stream.deserializeMsgType();
        if(type===MsgType.Join) {
          const join=new JoinMsg();
          join.deserialize(stream.getStream());
          if(join.protocol!==1028 ||
             !["Network Test","Spectator Test","Combat Test"].includes(join.name) ||
             join.joinToken!=="fixture-token")
            throw Error("invalid original TS JoinMsg fields");
          spectatorSession=join.name==="Spectator Test";
          combatSession=join.name==="Combat Test";
          joinSeen=true;
          const joined=new JoinedMsg();
          joined.teamMode=1;joined.playerId=7;joined.started=true;joined.emotes=[];
          const map=new MapMsg();
          map.mapName="main";map.seed=321;map.width=720;map.height=640;
          map.shoreInset=8;map.grassInset=12;
          const initial=update();
          if(combatSession) {
            initial.activePlayerData.inventoryDirty=true;
            initial.activePlayerData.scope="1xscope";
            initial.activePlayerData.inventory={"bandage":2,"9mm":15};
          }
          if(spectatorSession) {
            // Original TS object serialization: a dead local player and
            // two living players who are valid spectator targets.
            initial.fullObjects=[
              playerPayload(120,140,true,7,true),
              playerPayload(200,250,true,8,false),
              playerPayload(300,350,true,9,false),
            ];
          }
          const combined=Buffer.concat([
            framedMsg(MsgType.Joined,joined),
            framedMsg(MsgType.Map,map),
            framedMsg(MsgType.Update,initial)
          ]);
          // RFC fragmented binary message with interleaved PING.
          const half=Math.floor(combined.length/2);
          socket.write(serverFrame(combined.subarray(0,half),2,false));
          socket.write(serverFrame(Buffer.from("survev-ping"),9));
          socket.write(serverFrame(combined.subarray(half),0,true));
        } else if(type===MsgType.Spectate) {
          if(!joinSeen||!spectatorSession)throw Error("unexpected SpectateMsg");
          const msg=new SpectateMsg();
          msg.deserialize(stream.getStream());
          const expected=[
            SpectateAction.Begin,SpectateAction.Next,SpectateAction.Prev
          ][spectateIndex];
          if(msg.action!==expected)
            throw Error("source spectator action order mismatch");
          spectateIndex++;
          spectateSeen=true;
          // The mock server owns the target selection. It emits an actual
          // TS UpdateMsg as the *only* cause of Lua activeId changes.
          const snap=update();
          snap.activePlayerIdDirty=true;
          snap.activePlayerId=spectateIndex===2?9:8;
          snap.fullObjects=[];
          socket.write(serverFrame(framedMsg(MsgType.Update,snap)));
        } else if(type===MsgType.DropItem) {
          if(!joinSeen||!combatSession||combatStep!==6||dropSeen)
            throw Error("unexpected DropItemMsg");
          const item=new DropItemMsg();
          item.deserialize(stream.getStream());
          if(item.item!=="9mm"||item.weapIdx!==0)
            throw Error("invalid original drop inventory packet");
          dropSeen=true;
          const delta=update();
          delta.ack=0;delta.fullObjects=[];
          delta.activePlayerData.inventoryDirty=true;
          delta.activePlayerData.scope="1xscope";
          delta.activePlayerData.inventory={bandage:1,"9mm":0};
          socket.write(serverFrame(framedMsg(MsgType.Update,delta)));
        } else if(type===MsgType.Input) {
          if(!joinSeen)throw Error("Input before Join");
          const input=new InputMsg();
          input.deserialize(stream.getStream());
          if(input.seq===0)throw Error("missing InputMsg sequence");
          if(combatSession) {
            const check=(condition,why)=>{
              if(!condition)throw Error("combat step "+combatStep+": "+why);
            };
            const expectAction=(action)=>{
              check(input.inputs.length===1&&input.inputs[0]===action,
                "bad source enum action");
            };
            if(combatStep===0) {
              check(input.moveRight&&input.shootStart&&input.shootHold,
                "move + first gun fire");
              check(input.inputs.length===0&&!input.useItem,"fire must be bits");
              check(input.toMouseDir.x>.999 && input.toMouseLen>0,
                "original aim vector");
            } else if(combatStep===1) {
              check(input.moveRight&&!input.shootStart&&input.shootHold,
                "held automatic fire without duplicate start");
            } else if(combatStep===2) {
              check(!input.shootStart&&!input.shootHold&&!input.moveRight,
                "movement and gun trigger released");
              expectAction(Input.Interact);
            } else if(combatStep===3) {
              check(!input.shootHold&&!input.moveRight,"no held combat input");
              expectAction(Input.Reload);
            } else if(combatStep===4) {
              check(input.useItem==="bandage"&&input.inputs.length===0,
                "bandages use type string not Input enum");
            } else if(combatStep===5) {
              expectAction(Input.EquipSecondary);
              check(input.useItem==="","heal action must be one-shot");
            } else {
              throw Error("unexpected extra combat InputMsg");
            }
            ++combatStep;
            const delta=update();
            delta.ack=input.seq;delta.fullObjects=[];
            delta.partObjects=[playerPayload(120+combatStep*3,140,false)];
            delta.activePlayerData.healthDirty=true;
            delta.activePlayerData.health=combatStep>=5?90:80;
            if(combatStep===5) {
              delta.activePlayerData.inventoryDirty=true;
              delta.activePlayerData.scope="1xscope";
              delta.activePlayerData.inventory={bandage:1,"9mm":15};
            }
            socket.write(serverFrame(framedMsg(MsgType.Update,delta)));
          } else {
            const ack=update();ack.ack=input.seq;
            ack.fullObjects=[];
            ack.partObjects=[playerPayload(125,150,false)];
            socket.write(serverFrame(framedMsg(MsgType.Update,ack)));
          }
          inputSeen=true;
        } else throw Error("unknown original client packet "+type);
      }
    } catch(e){
      console.error("fixture server:",e);
      socket.destroy();
      process.exitCode=1;
    }
  });
  socket.on("close",()=>{
    if(!joinSeen||!(inputSeen||(spectateSeen&&spectateIndex===3))||!pongSeen
        ||(combatSession&&(combatStep!==6||!dropSeen))) {
      console.error("Fixture incomplete", {
        joinSeen,inputSeen,spectateSeen,spectateIndex,combatSession,
        combatStep,dropSeen,pongSeen
      });
      process.exitCode=1;
    }
  });
});
listen.listen(PORT,"127.0.0.1",()=>console.log("SURVEV_FIXTURE_READY:"+PORT));
