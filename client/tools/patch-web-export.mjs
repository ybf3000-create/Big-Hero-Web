import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(toolDirectory, "../..");
const gameDirectory = path.join(repositoryRoot, "SERVER", "public", "game");
const enginePath = path.join(gameDirectory, "index.js");
const shellPath = path.join(gameDirectory, "index.html");
const checkOnly = process.argv.includes("--check");

const secureContextOriginal = "if (!Features.isSecureContext()) {";
const secureContextPatched = "if (!Features.isSecureContext() && supportsThreads) {";
const audioWorkletOriginal =
  "GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path)";
const audioWorkletPatched =
  "GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve()";

function ensurePatched(content, original, patched, label) {
  if (content.includes(patched)) {
    return { content, changed: false };
  }
  if (!content.includes(original)) {
    throw new Error(`Cannot find the expected ${label} code in ${enginePath}`);
  }
  if (checkOnly) {
    throw new Error(`${label} compatibility patch is missing`);
  }
  return { content: content.replace(original, patched), changed: true };
}

const shell = await readFile(shellPath, "utf8");
if (!shell.includes("const GODOT_THREADS_ENABLED = false;")) {
  throw new Error("ZeroTier HTTP mode requires a non-threaded Godot Web export");
}

let engine = await readFile(enginePath, "utf8");
let changed = false;

for (const [original, patched, label] of [
  [secureContextOriginal, secureContextPatched, "secure-context"],
  [audioWorkletOriginal, audioWorkletPatched, "audio-worklet fallback"],
]) {
  const result = ensurePatched(engine, original, patched, label);
  engine = result.content;
  changed ||= result.changed;
}

if (changed) {
  await writeFile(enginePath, engine, "utf8");
  console.log("Patched Godot Web export for ZeroTier HTTP access.");
} else {
  console.log("Godot Web ZeroTier HTTP compatibility is ready.");
}
