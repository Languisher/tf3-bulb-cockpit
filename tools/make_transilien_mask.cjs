// Offline only. Requires Node.js and sharp; an absolute sharp module path can
// be passed as the first argument. The committed TGA needs neither at runtime.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.argv[2] || 'sharp');
const root = path.resolve(__dirname, '..');
(async () => {
  const { data, info } = await sharp(path.join(root, 'tools/assets/transilien-mode.svg'), { density: 144 })
    .resize(128, 128).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  if (info.channels !== 4) throw new Error('Expected RGBA');
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(128, 12); header.writeUInt16LE(128, 14);
  header[16] = 32; header[17] = 0x28;
  const pixels = Buffer.alloc(data.length);
  for (let i = 0; i < data.length; i += 4) {
    pixels[i] = pixels[i + 1] = pixels[i + 2] = 255;
    pixels[i + 3] = data[i + 3];
  }
  fs.writeFileSync(path.join(root, 'mod/content/gui/bulb_cockpit/symbols/transilien-mode.tga'),
    Buffer.concat([header, pixels]));
})().catch(error => { console.error(error); process.exitCode = 1; });
