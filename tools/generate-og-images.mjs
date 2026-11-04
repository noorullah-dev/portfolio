/**
 * Generates the 1200x630 social share card for every blog post.
 *
 * Reads the published blog pages themselves — title from the <h1>, category
 * from the JSON-LD articleSection — so the images always match what is live.
 * Output goes to assets/images/blog/<slug>.png and is referenced by each
 * post's og:image tag.
 *
 * Optional tool. Needs sharp, which is the only dependency in the project:
 *
 *   npm install sharp
 *   node tools/generate-og-images.mjs
 */
import { readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import sharp from 'sharp';

const ROOT = path.resolve(import.meta.dirname, '..');
const BLOG = path.join(ROOT, 'blog');
const OUT = path.join(ROOT, 'assets/images/blog');

const WIDTH = 1200;
const HEIGHT = 630;
const ACCENT = '#fb3602';

/* ------------------------------------------------------------------ */
/* Canvas                                                              */
/* ------------------------------------------------------------------ */

function canvas(title, category) {
  // Split the title into lines of roughly even length so it fills the card.
  const words = title.split(/\s+/);
  const lines = [];
  let line = '';
  const target = Math.ceil(title.length / 58);
  for (const word of words) {
    if ((line + ' ' + word).trim().length > target && line) {
      lines.push(line.trim());
      line = word;
    } else {
      line = (line + ' ' + word).trim();
    }
  }
  if (line) lines.push(line.trim());
  const shown = lines.slice(0, 4);

  const fontSize = shown.length >= 4 ? 44 : shown.length === 3 ? 52 : 60;
  const lineHeight = fontSize * 1.28;
  const startY = Math.round(HEIGHT / 2 - ((shown.length - 1) * lineHeight) / 2);

  const escaped = (s) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="#0d0d0f"/>
  <rect x="0" y="0" width="${WIDTH}" height="8" fill="${ACCENT}"/>
  <circle cx="${WIDTH - 90}" cy="86" r="150" fill="${ACCENT}" opacity="0.1"/>
  <text x="80" y="128" font-family="OverusedGrotesk, Arial, sans-serif" font-size="26"
        font-weight="700" letter-spacing="4" fill="${ACCENT}">${escaped(category.toUpperCase())}</text>
  <rect x="80" y="152" width="110" height="5" fill="${ACCENT}"/>
  ${shown
    .map(
      (l, i) =>
        `<text x="80" y="${startY + i * lineHeight}" font-family="OverusedGrotesk, Arial, sans-serif"
         font-size="${fontSize}" font-weight="700" fill="#f5f5f4">${escaped(l)}</text>`
    )
    .join('\n  ')}
  <text x="80" y="${HEIGHT - 62}" font-family="OverusedGrotesk, Arial, sans-serif"
        font-size="30" font-weight="600" fill="#9a9a97">Noor Ullah</text>
  <text x="${WIDTH - 80}" y="${HEIGHT - 62}" text-anchor="end"
        font-family="OverusedGrotesk, Arial, sans-serif" font-size="24" fill="#6b6b68">noorkhan.vercel.app</text>
</svg>`);
}

/* ------------------------------------------------------------------ */

const dirs = (await readdir(BLOG, { withFileTypes: true }))
  .filter((d) => d.isDirectory())
  .map((d) => d.name);

let made = 0;

for (const slug of dirs) {
  const file = path.join(BLOG, slug, 'index.html');
  let html;
  try {
    html = await readFile(file, 'utf8');
  } catch {
    continue;
  }

  const title =
    html.match(/<h1[^>]*>([^<]+)<\/h1>/)?.[1]?.trim() ??
    html.match(/<title>([^<]+)<\/title>/)?.[1]?.replace(/\s*\|\s*[^|]+$/, '').trim();
  if (!title) {
    console.warn(`skip ${slug}: no title found`);
    continue;
  }

  const category =
    html.match(/"articleSection"\s*:\s*"([^"]+)"/)?.[1] ??
    html.match(/post-item-tag"[^>]*>([^<]+)</)?.[1]?.trim() ??
    'Article';

  const png = await sharp(canvas(title, category))
    .png({ quality: 90, compressionLevel: 9 })
    .toBuffer();

  await writeFile(path.join(OUT, `${slug}.png`), png);
  console.log(`  ${slug}.png — ${title}`);
  made++;
}

console.log(`\nGenerated ${made} cover image(s).`);