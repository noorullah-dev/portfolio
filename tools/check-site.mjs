/**
 * Site check for the plain-HTML build.
 *
 * There is no build step, so this validates the files themselves: it walks
 * every .html file, resolves every local href/src the way a browser would,
 * and then audits the SEO essentials that silently break when someone edits
 * a file by hand.
 *
 *   node tools/check-site.mjs
 */
import { readFile, readdir, access } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { constants } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const SITE = 'https://noorkhan.vercel.app';

/** Directories that are not part of the published site. */
const SKIP_DIRS = new Set([
  '.git', '.astro', 'node_modules', 'src', 'dist', 'legacy', 'tools', '.originals',
]);

/** Not real files: remote URLs, anchors, mailto/tel, inline data. */
const EXTERNAL = /^(https?:|mailto:|tel:|data:|javascript:|#|\/\/)/;

const problems = [];
const warnings = [];
const fail = (page, msg) => problems.push(`${page} — ${msg}`);
const warn = (page, msg) => warnings.push(`${page} — ${msg}`);

async function htmlFiles(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      if (!SKIP_DIRS.has(entry.name)) out.push(...(await htmlFiles(path.join(dir, entry.name))));
    } else if (entry.name.endsWith('.html')) {
      out.push(path.join(dir, entry.name));
    }
  }
  return out;
}

const files = await htmlFiles(ROOT);
const pages = files.map((file) => ({
  file,
  rel: '/' + path.relative(ROOT, file).replace(/index\.html$/, ''),
  html: readFileSync(file, 'utf8'),
}));

const isNoindex = (html) => /name="robots"[^>]*content="[^"]*noindex/.test(html);
const readable = async (p) => {
  try {
    await access(p, constants.R_OK);
    return true;
  } catch {
    return false;
  }
};

/* ------------------------------------------------------------------ */
/* Per-page SEO                                                        */
/* ------------------------------------------------------------------ */

for (const { rel, file, html } of pages) {
  const head = html.slice(0, html.indexOf('</head>') + 7);

  const title = head.match(/<title>([\s\S]*?)<\/title>/)?.[1]?.trim();
  if (!title) fail(rel, 'missing <title>');
  else if (title.length > 65) warn(rel, `title is ${title.length} chars (aim 50-60)`);

  const desc = head.match(/name="description" content="([\s\S]*?)"/)?.[1];
  if (!desc) fail(rel, 'missing meta description');
  else if (desc.length > 170) warn(rel, `description is ${desc.length} chars (aim 110-160)`);

  if (!isNoindex(html)) {
    const canonical = head.match(/rel="canonical" href="([^"]+)"/)?.[1];
    if (!canonical) fail(rel, 'missing canonical');
    else if (new URL(canonical).pathname !== rel) {
      // A directory route is served by its index.html, so accept both forms.
      const cPath = new URL(canonical).pathname;
      const samePage =
        cPath === rel ||
        (cPath.endsWith('/') && rel === cPath + 'index.html') ||
        (rel.endsWith('/index.html') && cPath === rel.slice(0, -'index.html'.length));
      if (!samePage) {
        fail(rel, `canonical (${cPath}) does not match the page path (${rel})`);
      }
    }

    const ogUrl = head.match(/property="og:url" content="([^"]+)"/)?.[1];
    if (ogUrl && ogUrl !== canonical) fail(rel, 'og:url does not match canonical');

    if (!/property="og:image"/.test(head)) fail(rel, 'missing og:image');
    if (!/name="twitter:card"/.test(head)) fail(rel, 'missing twitter:card');
    if (!/rel="manifest"/.test(head)) warn(rel, 'missing web manifest link');
  }

  if (!/<html lang="[a-z]{2}/i.test(html)) fail(rel, 'missing or invalid <html lang>');
  if (!/name="viewport"/.test(head)) fail(rel, 'missing viewport meta');

  // Every SEO URL must be absolute, and must not have lost its separator.
  for (const m of html.matchAll(/(?:href|content)="(https:\/\/noorkhan\.vercel\.app[^"]*)"/g)) {
    if (/vercel\.app[a-z0-9]/i.test(m[1])) {
      fail(rel, `absolute URL is missing a "/" after the host: ${m[1]}`);
    }
  }

  for (const m of html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)) {
    try {
      const parsed = JSON.parse(m[1]);
      if (!parsed['@context']) fail(rel, 'JSON-LD missing @context');
      if (!parsed['@graph']?.length) fail(rel, 'JSON-LD @graph is empty');
    } catch (error) {
      fail(rel, `JSON-LD does not parse: ${error.message}`);
    }
  }

  const h1s = (html.match(/<h1[\s>]/g) || []).length;
  if (h1s === 0) fail(rel, 'no <h1>');
  if (h1s > 1) fail(rel, `${h1s} <h1> elements (should be exactly 1)`);

  const levels = [...html.matchAll(/<h([1-6])[\s>]/g)].map((m) => Number(m[1]));
  for (let i = 1; i < levels.length; i++) {
    if (levels[i] - levels[i - 1] > 1) {
      warn(rel, `heading jumps from h${levels[i - 1]} to h${levels[i]}`);
      break;
    }
  }

  for (const img of html.matchAll(/<img\s([^>]*?)\/?>/g)) {
    const attrs = img[1];
    const src = attrs.match(/(?:^|\s)src="([^"]+)"/)?.[1] ?? '(no src)';
    if (!/\salt="/.test(attrs)) fail(rel, `image without alt: ${src}`);
    if (!/\swidth="/.test(attrs) || !/\sheight="/.test(attrs)) {
      warn(rel, `image without width/height (layout shift): ${src}`);
    }
  }

  // Animated headings must keep text a crawler can read.
  for (const h of html.matchAll(/<h([1-6])[^>]*text-anime-style-3[^>]*>([\s\S]*?)<\/h\1>/g)) {
    if (!h[2].replace(/<[^>]+>/g, '').trim() && !/aria-label="/.test(h[0])) {
      fail(rel, `animated h${h[1]} has no crawlable text and no aria-label`);
    }
  }

  /* --- local file references --- */
  for (const m of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    const url = m[1].trim();
    if (!url || EXTERNAL.test(url)) continue;
    const clean = url.split('#')[0].split('?')[0];
    if (!clean) continue;
    const target = clean.startsWith('/')
      ? path.join(ROOT, clean)
      : path.resolve(path.dirname(file), clean);
    if (!(await readable(target))) fail(rel, `broken link: ${url}`);
  }
}

/* ------------------------------------------------------------------ */
/* Sitemap and robots                                                  */
/* ------------------------------------------------------------------ */

const sitemapUrls = new Set();
if (await readable(path.join(ROOT, 'sitemap-0.xml'))) {
  const xml = readFileSync(path.join(ROOT, 'sitemap-0.xml'), 'utf8');
  for (const m of xml.matchAll(/<loc>([^<]+)<\/loc>/g)) {
    if (!/\.xml$/.test(m[1])) sitemapUrls.add(new URL(m[1]).pathname);
  }
}
if (sitemapUrls.size) {
  for (const { rel, html } of pages) {
    if (isNoindex(html) || rel === '/404.html') continue;
    if (!sitemapUrls.has(rel)) fail(rel, 'indexable page missing from sitemap');
  }
  for (const url of sitemapUrls) {
    if (url.includes('404')) fail('/sitemap-0.xml', '404 page is present in the sitemap');
  }
}

/* ------------------------------------------------------------------ */

const indexable = pages.filter((p) => !isNoindex(p.html));
const images = pages.reduce((n, p) => n + (p.html.match(/<img\s/g) || []).length, 0);
const withAlt = pages.reduce((n, p) => n + (p.html.match(/<img\s[^>]*\salt="/g) || []).length, 0);

console.log(`\n  Pages        ${pages.length} (${indexable.length} indexable)`);
console.log(`  Sitemap      ${sitemapUrls.size} URLs`);
console.log(`  Images       ${images} (${withAlt} with alt text)`);
console.log(`  Total HTML   ${(pages.reduce((n, p) => n + p.html.length, 0) / 1024).toFixed(0)} KB\n`);

if (warnings.length) {
  console.log(`WARNINGS (${warnings.length})`);
  for (const w of warnings) console.log(`  ! ${w}`);
  console.log('');
}

if (problems.length) {
  console.log(`PROBLEMS (${problems.length})`);
  for (const p of problems) console.log(`  x ${p}`);
  console.log('');
  process.exit(1);
}

console.log('No problems found.\n');