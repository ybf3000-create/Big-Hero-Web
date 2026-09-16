import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));
const source = path.join(root, "src");
const output = path.resolve(root, "../SERVER/public/game");
const assetRoot = path.resolve(root, "../client/assets");

fs.rmSync(output, { recursive: true, force: true });
fs.mkdirSync(output, { recursive: true });
for (const file of ["index.html", "app.js", "styles.css"]) {
  fs.copyFileSync(path.join(source, file), path.join(output, file));
}
fs.mkdirSync(path.join(output, "assets", "battle"), { recursive: true });
fs.copyFileSync(path.join(assetRoot, "主角.png"), path.join(output, "assets", "map-hero.png"));
fs.copyFileSync(path.join(assetRoot, "hreo.png"), path.join(output, "assets", "battle-hero.png"));
fs.cpSync(path.join(assetRoot, "battle_characters", "boss"), path.join(output, "assets", "battle", "boss"), { recursive: true, filter: (entry) => !entry.endsWith(".import") });
fs.cpSync(path.join(assetRoot, "battle_characters", "monsters"), path.join(output, "assets", "battle", "monsters"), { recursive: true, filter: (entry) => !entry.endsWith(".import") });
fs.cpSync(path.join(assetRoot, "equipment_icons"), path.join(output, "assets", "equipment"), { recursive: true, filter: (entry) => !entry.endsWith(".import") });
for (const folder of ["weapon", "armor", "shoes", "ring", "charm", "helmet"]) {
  const sourceFolder = path.join(assetRoot, "equipment_icons", folder);
  const representative = fs.readdirSync(sourceFolder).find((file) => /\.(png|jpe?g|webp)$/i.test(file));
  if (representative) fs.copyFileSync(path.join(sourceFolder, representative), path.join(output, "assets", "equipment", folder, "default.png"));
}
console.log(`Built web client to ${output}`);
