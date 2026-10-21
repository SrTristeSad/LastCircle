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
const { GameConfig } = await load("shared/gameConfig.ts");
const { GameObjectDefs } = await load("shared/defs/register.ts");

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

console.log("original Node TypeScript reference:", commit);
console.log("JoinMsg    " + joinHex);
console.log("InputMsg   " + inputHex);
const result = spawnSync(lua, ["tests/bitstream_parity.lua",plain,joinHex,inputHex], {
  encoding: "utf8", cwd: process.cwd()
});
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
if (result.error) throw result.error;
if (result.status !== 0) throw Error("Lua packet parity failed (exit " + result.status + ")");
