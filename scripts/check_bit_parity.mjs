/**
 * Compare real TypeScript upstream packets byte for byte with LastCircle Lua.
 * No handwritten expected bytes. This must fail if the original protocol differs.
 *
 * node --experimental-transform-types scripts/check_bit_parity.mjs
 *    <reference/survev> [lua-interpreter]
 */
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";

const root = resolve(process.argv[2] || "");
const lua = process.argv[3] || "lua5.4";
const commit = "c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if (!(await readFile(resolve(root, "../ORIGEM.txt"), "utf8")).includes(commit)) {
  throw Error("unrecognized reference revision");
}
const load = async (path) => await import(pathToFileURL(resolve(root, path)).href);
const { BitStream: OriginalBitStream } = await load("shared/lib/bitBuffer.ts");
const { MsgStream, MsgType } = await load("shared/net/net.ts");
const { JoinMsg } = await load("shared/net/joinMsg.ts");
const { InputMsg } = await load("shared/net/inputMsg.ts");
const { MapMsg } = await load("shared/net/mapMsg.ts");
const { JoinedMsg } = await load("shared/net/joinedMsg.ts");
const { AliveCountsMsg } = await load("shared/net/aliveCountsMsg.ts");
const { PickupMsg } = await load("shared/net/pickupMsg.ts");
const { KillMsg } = await load("shared/net/killMsg.ts");
const { EmoteMsg } = await load("shared/net/emoteMsg.ts");
const { DropItemMsg } = await load("shared/net/dropItemMsg.ts");
const { SpectateMsg } = await load("shared/net/spectateMsg.ts");
const { PlayerStatsMsg } = await load("shared/net/playerStatsMsg.ts");
const { GameOverMsg } = await load("shared/net/gameOverMsg.ts");
const { RoleAnnouncementMsg } = await load("shared/net/roleAnnouncementMsg.ts");
const { GameConfig } = await load("shared/gameConfig.ts");
const { GameObjectDefs, MapObjectDefs } = await load("shared/defs/register.ts");

function hex(s) {
  const array = new Uint8Array(s.buffer, 0, s.byteIndex);
  return Buffer.from(array).toString("hex");
}
function msgHex(s) {
  return Buffer.from(s.getBuffer()).toString("hex");
}
const primitive = new OriginalBitStream(new ArrayBuffer(128));
primitive.writeBits(5,3);
primitive.writeUint16(48879);
primitive.writeInt8(-12);
primitive.writeBoolean(true);
primitive.writeASCIIString("OK",4);
primitive.writeFloat32(3.25);
const plain = hex(primitive);

const join = new JoinMsg();
join.protocol = GameConfig.protocolVersion;
join.joinToken = "test-token";
join.name = "Alex";
join.loadout.outfit = "outfitBase";
const joinStream = new MsgStream(new ArrayBuffer(256));
joinStream.serializeMsg(MsgType.Join,join);
const joinHex = msgHex(joinStream);

const input = new InputMsg();
input.seq=31;
input.moveLeft=true;
input.moveUp=true;
input.shootStart=true;
input.touchMoveActive=true;
input.touchMoveDir={x:0,y:1};
input.touchMoveLen=201;
input.toMouseDir={x:1,y:0};
input.toMouseLen=27.25;
input.addInput(GameConfig.Input.Reload);
input.addInput(GameConfig.Input.EquipMelee);
input.useItem="bandage";
if (GameObjectDefs.typeToId("bandage") < 1) throw Error("original register missing bandage");
const inputStream = new MsgStream(new ArrayBuffer(256));
inputStream.serializeMsg(MsgType.Input,input);
const inputHex = msgHex(inputStream);

const map = new MapMsg();
map.mapName="main";
map.seed=123456;
map.width=720;
map.height=640;
map.shoreInset=8;
map.grassInset=12;
map.rivers=[{width:7,looped:false,points:[{x:20,y:30},{x:48,y:75}]}];
map.places=[{name:"Town",pos:{x:.25,y:.65}}];
map.objects=[{pos:{x:200,y:150},scale:1,type:MapObjectDefs.getAllTypes()[0],ori:2}];
map.groundPatches=[
  {bound:{type:0,pos:{x:300,y:200},rad:17},color:0x113355,roughness:.25,offsetDist:3.5,order:2,useAsMapShape:true},
  {bound:{type:1,min:{x:50,y:100},max:{x:100,y:140}},color:0x8899aa,roughness:.5,offsetDist:1.25,order:1,useAsMapShape:false},
];
const mapStream = new MsgStream(new ArrayBuffer(2048));
mapStream.serializeMsg(MsgType.Map,map);
const mapHex=msgHex(mapStream);

const messages = new MsgStream(new ArrayBuffer(1024));
const joinedMsg = new JoinedMsg();
joinedMsg.teamMode=2;
joinedMsg.playerId=481;
joinedMsg.started=true;
joinedMsg.emotes=["emote_happyface"];
messages.serializeMsg(MsgType.Joined,joinedMsg);

const counts = new AliveCountsMsg();
counts.teamAliveCounts=[10,7];
messages.serializeMsg(MsgType.AliveCounts,counts);

const pickup = new PickupMsg();
pickup.type=4;
pickup.item="bandage";
pickup.count=2;
messages.serializeMsg(MsgType.Pickup,pickup);

const kill = new KillMsg();
kill.damageType=0;
kill.itemSourceType="bandage";
kill.mapSourceType="";
kill.targetId=5;
kill.killerId=22;
kill.killCreditId=22;
kill.killerKills=2;
kill.killed=true;
kill.downed=false;
messages.serializeMsg(MsgType.Kill,kill);

const emote = new EmoteMsg();
emote.pos={x:100,y:200};
emote.type="emote_happyface";
emote.isPing=true;
messages.serializeMsg(MsgType.Emote,emote);

const drop = new DropItemMsg();
drop.item="bandage";
drop.weapIdx=1;
messages.serializeMsg(MsgType.DropItem,drop);

const spectate = new SpectateMsg();
spectate.action=2;
messages.serializeMsg(MsgType.Spectate,spectate);

const stats = new PlayerStatsMsg();
stats.playerStats={playerId:481,timeAlive:87,kills:3,dead:true,damageDealt:149.6,damageTaken:51.4};
messages.serializeMsg(MsgType.PlayerStats,stats);

const gameOver = new GameOverMsg();
gameOver.teamId=4;
gameOver.teamRank=2;
gameOver.gameOver=true;
gameOver.winningTeamId=3;
gameOver.playerStats=[stats.playerStats];
messages.serializeMsg(MsgType.GameOver,gameOver);

const role = new RoleAnnouncementMsg();
role.playerId=481;
role.killerId=222;
role.role="";
role.assigned=true;
role.killed=false;
messages.serializeMsg(MsgType.RoleAnnouncement,role);
const batchHex=msgHex(messages);

console.log("original Node TypeScript reference:", commit);
console.log("JoinMsg    " + joinHex);
console.log("InputMsg   " + inputHex);
console.log("MapMsg     " + mapHex);
console.log("Msg batch  " + batchHex);
const result = spawnSync(lua, ["tests/bitstream_parity.lua",plain,joinHex,inputHex,mapHex], {
  encoding: "utf8", cwd: process.cwd()
});
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
if (result.error) throw result.error;
if (result.status !== 0) throw Error("Lua packet parity failed (exit " + result.status + ")");
const batch = spawnSync(lua, ["tests/packet_batch_parity.lua", batchHex], {
  encoding: "utf8", cwd: process.cwd()
});
process.stdout.write(batch.stdout);
process.stderr.write(batch.stderr);
if (batch.error) throw batch.error;
if (batch.status !== 0) throw Error("Lua batched-message parity failed (exit " + batch.status + ")");

