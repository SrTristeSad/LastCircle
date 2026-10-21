/**
 * Generate exactly ordered Lua IDs from the pinned Survev TypeScript registry.
 * Usage: node --experimental-transform-types scripts/generate_type_registry.mjs
 *   <reference/survev> <output.lua>
 * The original registry is the sole source of truth. No manual ID assignments.
 */
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { pathToFileURL } from "node:url";

const [upstreamArg, destinationArg] = process.argv.slice(2);
if (!upstreamArg || !destinationArg) {
  throw Error("usage: generate_type_registry.mjs <reference/survev> <output.lua>");
}
const root = resolve(upstreamArg);
const dest = resolve(destinationArg);
const origin = await readFile(resolve(root, "../ORIGEM.txt"), "utf8");
const commit = "c6185e31fe25a4a07def77a2bb25b1710bda90ac";
if (!origin.includes(commit)) {
  throw Error("reference commit is not pinned to " + commit);
}
const src = pathToFileURL(resolve(root, "shared/defs/register.ts")).href;
const { GameObjectDefs, MapObjectDefs } = await import(src);

function buildSection(name, registry, bits) {
  const types = registry.getAllTypes();
  if (types.length >= 2 ** bits) {
    throw Error(name + " exceeds " + bits + "-bit field");
  }
  if (new Set(types).size !== types.length) {
    throw Error("duplicate " + name + " definitions");
  }
  const luaString = (s) => {
    if (!/^[\x20-\x7e]+$/.test(s)) throw Error("unsupported type id text: " + s);
    return JSON.stringify(s);
  };
  let str = "    " + name + " = {\n        typeToId = {[\"\"] = 0,\n";
  for (let i = 0; i < types.length; i++) {
    const t = types[i];
    const id = registry.typeToId(t);
    if (id !== i + 1) throw Error("unexpected " + name + " type ID for " + t + ": " + id);
    str += "            [" + luaString(t) + "] = " + id + ",\n";
  }
  str += "        },\n        idToType = {[0] = \"\",\n";
  for (let i = 0; i < types.length; i++) {
    str += "            [" + (i + 1) + "] = " + luaString(types[i]) + ",\n";
  }
  str += "        },\n";
  str += "        count = " + (types.length + 1) + ",\n";
  str += "    },\n";
  return [str, types.length + 1];
}
const [game, gameCount] = buildSection("game", GameObjectDefs, 10);
const [map, mapCount] = buildSection("map", MapObjectDefs, 12);
const out = [
  "-- AUTO-GENERATED from survev/survev shared/defs/register.ts",
  "-- Upstream commit " + commit,
  "-- Includes ID zero for empty string. GPL-3.0; do not reorder.",
  "return {",
  game.trimEnd(),
  map.trimEnd(),
  "}\n",
].join("\n");
await mkdir(dirname(dest), { recursive: true });
await writeFile(dest, out, "utf8");
console.log("Registry generated: game=" + gameCount + ", map=" + mapCount + ", " + out.length + " characters");
