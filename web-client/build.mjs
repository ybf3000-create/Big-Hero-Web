import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const source = path.join(root, "src");
const output = path.resolve(root, "../SERVER/public/game");
const asset = path.resolve(root, "../client/assets/主角.png");

fs.rmSync(output, { recursive: true, force: true });
fs.mkdirSync(output, { recursive: true });
for (const file of ["index.html", "app.js", "styles.css"]) {
  fs.copyFileSync(path.join(source, file), path.join(output, file));
}
fs.copyFileSync(asset, path.join(output, "hero.png"));
console.log(`Built web client to ${output}`);
