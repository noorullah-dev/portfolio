/**
 * Rebuilds every page from the pristine original theme markup in .originals/.
 *
 * The theme's <body> markup is copied through verbatim, so the design-critical
 * parts all survive: per-character heading spans (class="split-line"), the
 * WOW.js reveal states baked into inline styles, and the <!-- Section -->
 * comments.
 *
 * Only these things change, none of them visible:
 *   - <head>: the theme's empty <title>/description/keywords/author tags are
 *     replaced with real SEO tags
 *   - "./assets/..." becomes depth-correct relative paths; old hashed page
 *     filenames become the clean routes
 *   - <img> gains alt text, and width/height where we can read them
 *   - placeholder copy in the pricing cards and FAQ answers is swapped for
 *     real copy (the only content edits, and they were approved)
 *   - blog posts are rendered into the original blog templates
 *
 *   node tools/build-html.mjs
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const ORIG = path.join(ROOT, '.originals');

/* ================================================================== */
/* Site                                                                */
/* ================================================================== */

const SITE = {
  origin: 'https://noorkhan.vercel.app',
  name: 'Noor Ullah',
  role: 'Ruby on Rails Developer',
  email: 'noor102bs@gmail.com',
  phone: '+92 310 9508764',
  phoneHref: '+923109508764',
  locale: 'en_US',
  profileImage: 'assets/images/about-me_o9pkwcvuk0s8.png',
  ogDefault: 'assets/images/og-default.png',
  sameAs: ['https://github.com/', 'https://www.linkedin.com/', 'https://x.com/'],
};

/* ================================================================== */
/* Small helpers                                                       */
/* ================================================================== */

const esc = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** Image dimensions from the file header — no dependencies. */
function imageSize(file) {
  let buf;
  try {
    buf = readFileSync(path.join(ROOT, file));
  } catch {
    return null;
  }

  const head = buf.slice(0, 2048).toString('latin1');
  if (head.includes('<svg')) {
    const vb = head.match(/viewBox\s*=\s*"([\d.\s-]+)"/i);
    if (vb) {
      const p = vb[1].split(/[\s,]+/).map(Number);
      if (p.length === 4 && p[2] > 0 && p[3] > 0) return { w: Math.round(p[2]), h: Math.round(p[3]) };
    }
    const w = head.match(/\bwidth\s*=\s*"([\d.]+)"/i);
    const h = head.match(/\bheight\s*=\s*"([\d.]+)"/i);
    if (w && h) return { w: Math.round(+w[1]), h: Math.round(+h[1]) };
    return null;
  }
  if (buf.readUInt32BE(0) === 0x89504e47) return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
  if (buf.slice(0, 3).toString('latin1') === 'GIF') return { w: buf.readUInt16LE(6), h: buf.readUInt16LE(8) };
  if (buf.slice(0, 4).toString('latin1') === 'RIFF' && buf.slice(8, 12).toString('latin1') === 'WEBP') {
    const fmt = buf.slice(12, 16).toString('latin1');
    if (fmt === 'VP8 ') return { w: buf.readUInt16LE(26) & 0x3fff, h: buf.readUInt16LE(28) & 0x3fff };
    if (fmt === 'VP8L') {
      const b = buf.readUInt32LE(21);
      return { w: (b & 0x3fff) + 1, h: ((b >> 14) & 0x3fff) + 1 };
    }
    if (fmt === 'VP8X') {
      return {
        w: (buf[24] | (buf[25] << 8) | (buf[26] << 16)) + 1,
        h: (buf[27] | (buf[28] << 8) | (buf[29] << 16)) + 1,
      };
    }
  }
  if (buf.readUInt16BE(0) === 0xffd8) {
    let i = 2;
    while (i < buf.length - 9) {
      if (buf[i] !== 0xff) { i++; continue; }
      const marker = buf[i + 1];
      if (marker === 0xd8 || marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) { i += 2; continue; }
      const len = buf.readUInt16BE(i + 2);
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        return { h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
      }
      i += 2 + len;
    }
  }
  return null;
}

/** Reproduce the theme's SplitText heading markup so it renders pre-JS. */
function splitHeading(text, { perLine = 4, tag = 'h1', extra = '' } = {}) {
  const words = text.split(/\s+/).filter(Boolean);
  const lines = [];
  for (let i = 0; i < words.length; i += perLine) lines.push(words.slice(i, i + perLine));

  const inner = lines
    .map((line) => {
      const wordDivs = line
        .map(
          (word) =>
            `<div aria-hidden="true" style="position: relative; display: inline-block;"><div aria-hidden="true" style="position: relative; display: inline-block;">${esc(word)}</div></div>`
        )
        .join(' ');
      return `<div class="split-line" aria-hidden="true" style="position: relative; display: block; text-align: start;">${wordDivs}</div>`;
    })
    .join('');

  return `<${tag} class="text-anime-style-3" data-cursor="-opaque"${extra} aria-label="${esc(text)}"${inner ? `>${inner}</${tag}>` : `>${esc(text)}</${tag}>`}`;
}

/**
 * Strip the furniture the earlier Astro layout added at the end of each post,
 * so the body contains only article content. The theme renders its own tags
 * and social links in the post-tag-links block below the article.
 */
function cleanBody(html) {
  return html
    // <p class="blog-post-tags"> ... post-item-tag chips ... </p>
    .replace(/<p class="blog-post-tags"[\s\S]*?<\/p>/gi, '')
    // the "← All articles / Hire me for Rails work →" line
    .replace(/<p[^>]*>[^<]*<a href="[^"]*blog[^"]*"[^>]*>\s*←\s*All articles[\s\S]*?<\/p>/gi, '')
    .replace(/<p[^>]*>[^<]*Hire me for Rails work[\s\S]*?<\/p>/gi, '')
    .trim();
}

/** Add the theme's WOW.js reveal classes to top-level blocks of content. */
function addWow(html, { step = 0.2, max = 1.4 } = {}) {
  const VOID = new Set(['br', 'hr', 'img', 'input', 'meta', 'link', 'source', 'col', 'area', 'base', 'wbr']);
  const WANT = new Set(['p', 'h2', 'h3', 'h4', 'ul', 'ol', 'blockquote', 'pre', 'figure', 'table', 'img', 'hr']);
  const re = /<(\/?)([a-zA-Z][\w-]*)((?:"[^"]*"|'[^']*'|[^>"'])*?)(\/?)>/g;

  let out = '';
  let depth = 0;
  let open = null;
  let n = 0;
  let m;

  while ((m = re.exec(html))) {
    const [full, close, , , selfClose] = m;
    const name = m[2].toLowerCase();

    if (!close) {
      if (depth === 0) open = { name, tagText: full, start: m.index };
      if (!selfClose && !VOID.has(name)) depth++;
      continue;
    }

    depth--;
    if (depth === 0 && open) {
      const raw = html.slice(open.start, re.lastIndex);
      const head = WANT.has(open.name) ? decorate(open.tagText, n++) : open.tagText;
      out += head + raw.slice(open.tagText.length);
      open = null;
    }
  }
  return out;

  function decorate(tagText, i) {
    let t = tagText;
    if (/\bclass\s*=/.test(t)) {
      t = t.replace(/\bclass\s*=\s*"([^"]*)"/, (all, cls) => (/\bwow\b/.test(cls) ? all : `class="${cls} wow fadeInUp"`));
    } else {
      t = t.replace(/^<([a-zA-Z][\w-]*)/, `<$1 class="wow fadeInUp"`);
    }
    if (!/\bdata-wow-delay\s*=/.test(t)) {
      // Cap the stagger: a 60-block article must not leave its last paragraph
      // hidden for ten seconds. The theme's own template tops out at 1.4s.
      t = t.replace(/\s*\/?>$/, (end) => ` data-wow-delay="${Math.min(i * step, max).toFixed(1)}s"${end}`);
    }
    return t;
  }
}

/* ================================================================== */
/* Approved content edits                                              */
/* ================================================================== */

const PRICING = [
  {
    span: 'Project Build',
    price: 'Fixed scope<sub>/per project</sub>',
    copy: 'A defined piece of work delivered to an agreed scope and deadline, quoted after a short call.',
    items: [
      'Ruby on Rails web application or feature set',
      'Hotwire Native app for iOS and Android',
      'PostgreSQL schema and REST or JSON API',
      'Automated tests, deployment setup and handover documentation',
      'Two weeks of post-launch fixes included',
    ],
    btn: 'Discuss your project',
  },
  {
    span: 'Monthly Retainer',
    price: 'Ongoing<sub>/per month</sub>',
    copy: 'Ongoing Rails work for teams that need steady delivery without hiring full time.',
    items: [
      'Feature development and bug fixes on an agreed backlog',
      'Performance, security and dependency maintenance',
      'Code review and pairing with your existing team',
      'Monitoring, backups and CI improvements',
      'Weekly written progress update',
    ],
    btn: 'Check availability',
  },
  {
    span: 'Consulting & Audit',
    price: 'Hourly<sub>/as needed</sub>',
    copy: 'Focused help when you need a second opinion or someone to untangle a hard problem.',
    items: [
      'Rails and application architecture review',
      'Hotwire Native and mobile build guidance',
      'Performance profiling and query optimisation',
      'Upgrade planning and dependency risk assessment',
      'Technical writing for your team',
    ],
    btn: 'Book a call',
  },
];

const FAQS = [
  ['Q1. What services do you offer?',
   'I build Ruby on Rails web applications, Hotwire Native mobile apps for iOS and Android, and the REST or JSON APIs behind them. I also take on performance work, code reviews and Rails upgrades.'],
  ['Q2. How long does it take to complete a project?',
   'A focused feature usually takes one to two weeks. A full application takes six to twelve weeks depending on scope. I agree a timeline with you before any work starts, and you see progress every week.'],
  ['Q3. Do you work with international clients?',
   'Yes. I work remotely with clients in Europe, North America, the Gulf and Asia Pacific. I keep a few hours of overlap with European and US Eastern working hours, and I write in plain English rather than jargon.'],
  ['Q4. Can I request changes after the project is delivered?',
   'Of course. Every project includes two weeks of fixes after handover. After that you can book a maintenance retainer, or I can quote a one-off change if it is small enough.'],
  ['Q5. Do you provide website maintenance services?',
   'Yes. A monthly retainer covers dependency and security updates, monitoring and backups, performance work, and a standing allocation of hours for new features and fixes.'],
  ['Q6. How can I start a project with you?',
   'Send an email to noor102bs@gmail.com or call +92 310 9508764 with a short description of what you need. I reply within one business day and we set up a 30-minute call to scope the work and give you a quote.'],
  ['Q7. What tools and technologies do you use?',
   'Ruby on Rails, PostgreSQL, Hotwire, Turbo, Stimulus, Redis, Sidekiq, RSpec, Docker and standard deployment tooling such as Kamal. I use whatever fits your existing codebase rather than forcing a rewrite.'],
  ['Q8. Do you offer custom design solutions?',
   'I can work from a Figma file, or build the interface in your existing design system. If you need a design as well as the code, I work with a designer and implement their files faithfully.'],
];

/** Replace the three pricing cards' text, keeping their markup intact. */
function applyPricing(html) {
  const re = /<div class="pricing-item-royal box-border-gradiant wow fadeInUp"([^>]*)>([\s\S]*?)<!-- Pricing Item End -->/g;
  const found = [...html.matchAll(re)];
  if (found.length !== 3) throw new Error(`expected 3 pricing cards, found ${found.length}`);

  const END = '<!-- Pricing Item End -->';

  let out = html;
  for (let i = found.length - 1; i >= 0; i--) {
    const m = found[i];
    const spec = PRICING[i];
    let card = m[2];

    card = card.replace(/(<div class="pricing-item-header-content-royal">\s*<span>)[^<]*(<\/span>)/, (all, open, close) => `${open}${spec.span}${close}`);
    card = card.replace(/(<div class="pricing-item-header-content-royal">[\s\S]*?<h2>)[\s\S]*?(<\/h2>)/, (all, open, close) => `${open}${spec.price}${close}`);
    card = card.replace(/(<div class="pricing-item-content-royal">\s*<p>)[\s\S]*?(<\/p>)/, (all, open, close) => `${open}${spec.copy}${close}`);
    card = card.replace(
      /(<div class="pricing-item-list-royal">[\s\S]*?<ul>)[\s\S]*?(<\/ul>)/,
      (all, open, close) => `${open}\n${spec.items.map((t) => `                                        <li>${t}</li>`).join('\n')}\n                                    ${close}`
    );
    card = card.replace(/(<div class="pricing-item-btn-royal">[\s\S]*?<a[^>]*class="btn-default"[^>]*>)[\s\S]*?(<\/a>)/, (all, open, close) => `${open}${spec.btn}${close}`);

    // m[0] === openTag + card + END
    const openTag = m[0].slice(0, m[0].length - m[2].length - END.length);
    out = out.slice(0, m.index) + openTag + card + END + out.slice(m.index + m[0].length);
  }
  return out;
}

/** Replace FAQ questions and answers, keeping the accordion markup intact. */
function applyFaqs(html) {
  let out = html;
  for (const [i, [q, a]] of FAQS.entries()) {
    const n = i + 1;
    out = out.replace(
      new RegExp(`(aria-controls="collapse${n}">)[\\s\\S]*?(</button>)`),
      `$1 ${q} $2`
    );

    const bodyRe = /<div class="accordion-body">\s*<p>[\s\S]*?<\/p>\s*<\/div>/g;
    let m, idx = -1, count = 0;
    while ((m = bodyRe.exec(out))) {
      if (count === i) { idx = m.index; break; }
      count++;
    }
    if (idx >= 0) {
      out = out.slice(0, idx) + `<div class="accordion-body">\n                                        <p>${a}</p>\n                                    </div>` + out.slice(idx + m[0].length);
    }
  }
  return out;
}

/* ================================================================== */
/* Paths                                                               */
/* ================================================================== */

const ROUTE_MAP = {
  'index.html': '/',
  'about_ab2b6b24ed67.html': '/about/',
  'services_327fd057821f.html': '/services/',
  'projects_b6cd068b4053.html': '/projects/',
  'project-single_5fdc0c52313a.html': '/projects/misrprime/',
  'contact_905cd97f5bea.html': '/contact/',
  '404_3e7303b6ce4a.html': '/404.html',
  'blog_b88d6ef39e72.html': '/blog/',
  'blog-single_4a7c29f5f9af.html': '/blog/ruby-on-rails-vs-django/',
  'faqs_a167135a0fc3.html': '/',
  // leftover demo pages the template links to from the menu and footer
  'index_cb58768fbae5.html': '/',
  'index_b9c495890196.html': '/',
  'index-2_2b021635a8e5.html': '/',
  'testimonials_2b757f7adcae.html': '/',
  'pricing_6643dbca52bb.html': '/',
  'service-single_1a47403f6e79.html': '/services/',
};

const ROUTE_TO_URL = {
  'index.html': '/',
  'about/index.html': '/about/',
  'services/index.html': '/services/',
  'projects/index.html': '/projects/',
  'projects/misrprime/index.html': '/projects/misrprime/',
  'contact/index.html': '/contact/',
  'blog/index.html': '/blog/',
  '404.html': '/404.html',
};

const up = (outFile) => '../'.repeat(outFile.split('/').length - 1);

/* ================================================================== */
/* Transforms                                                          */
/* ================================================================== */

/** Map a site-absolute route to a path relative to the output file. */
function routeToRelative(route, outFile) {
  const prefix = up(outFile);
  // "/" is served by index.html at the site root — an empty href would make
  // the browser reload the current page instead.
  return route === '/' ? `${prefix}index.html` : prefix + route.replace(/^\//, '');
}

function rewritePaths(html, outFile) {
  return html.replace(/\s(href|src)\s*=\s*"([^"]*)"/gi, (all, attr, url) => {
    if (!url || url.startsWith('#')) return all;
    if (/^(https?:|mailto:|tel:|data:|javascript:)/i.test(url)) return all;

    if (url.startsWith('/')) {
      return ` ${attr}="${routeToRelative(url, outFile)}"`;
    }

    const base = url.split('#')[0].split('?')[0];
    if (ROUTE_MAP[base]) {
      return ` ${attr}="${routeToRelative(ROUTE_MAP[base], outFile) + url.slice(base.length)}"`;
    }
    if (url.startsWith('./assets/')) return ` ${attr}="${up(outFile) + url.slice(2)}"`;
    if (url.startsWith('assets/')) return ` ${attr}="${up(outFile) + url}"`;
    return all;
  });
}

/** Index just past the </ul> that closes the <ul> starting at `from`. */
function matchingUlEnd(html, from) {
  let depth = 0;
  const re = /<(\/?)ul\b[^>]*>/gi;
  re.lastIndex = from;
  let m;
  while ((m = re.exec(html))) {
    if (!m[1]) depth++;
    else if (--depth === 0) return re.lastIndex;
  }
  return -1;
}

const NAV_ITEMS = [
  ['/', 'Home'],
  ['/about/', 'About Us'],
  ['/services/', 'Services'],
  ['/projects/', 'Projects'],
  ['/blog/', 'Blog'],
  ['/contact/', 'Contact Us'],
];

/**
 * Replace the template's menu and footer links with one clean, correct set.
 *
 * The template ships two variants: the static pages have a flat menu, the blog
 * pages have a "Home" submenu plus a "Pages" dropdown full of demo pages
 * (Home Version 1/2/3, Service Details, Pricing Plan, FAQs, 404 …) that do not
 * exist as pages. Every link below uses the template's own <li>/<a> markup, so
 * the styling is untouched — only the link targets change. Absolute routes are
 * used so rewritePaths() can make them correct at any folder depth.
 */
function normalizeNav(html) {
  let out = html;

  const items = NAV_ITEMS.map(
    ([href, label]) =>
      `<li class="nav-item"><a class="nav-link" href="${href}">${label}</a></li>`
  ).join('');

  const menuStart = out.search(/<ul class="navbar-nav mr-auto" id="menu">/);
  if (menuStart >= 0) {
    const open = out.indexOf('>', menuStart) + 1;
    const end = matchingUlEnd(out, menuStart);
    if (end > 0) out = out.slice(0, open) + items + out.slice(end);
  }

  const footerStart = out.search(/<h2>Quick Links<\/h2>/);
  if (footerStart >= 0) {
    const ulStart = out.indexOf('<ul>', footerStart);
    if (ulStart >= 0) {
      const open = ulStart + 4;
      const end = matchingUlEnd(out, ulStart);
      if (end > 0) {
        const footItems = NAV_ITEMS.map(([href, label]) => `<li><a href="${href}">${label}</a></li>`).join('');
        out = out.slice(0, open) + footItems + out.slice(end);
      }
    }
  }

  // The logo goes home too.
  out = out.replace(/(<a class="navbar-brand")\s+href="[^"]*"/, '$1 href="/"');

  // Each page carries a second copy of the menu for the SlickNav mobile
  // drawer. On the blog templates it still has the template's submenus, so
  // rebuild it with the same flat markup the other pages use.
  const sliceStart = out.search(/<ul class="slicknav_nav[^"]*"[^>]*>/);
  if (sliceStart >= 0) {
    const open = out.indexOf('>', sliceStart) + 1;
    const end = matchingUlEnd(out, sliceStart);
    if (end > 0) {
      const sliceItems = NAV_ITEMS.map(
        ([href, label]) =>
          `<li class="nav-item"><a class="nav-link" href="${href}" role="menuitem" tabindex="-1">${label}</a></li>`
      ).join('');
      out = out.slice(0, open) + sliceItems + out.slice(end);
    }
  }

  return out;
}

function fixImages(html) {
  return html.replace(/<img\b([^>]*?)(\/?)>/gi, (all, attrs) => {
    let a = attrs;
    if (!/\balt\s*=/i.test(a)) a += ' alt=""';

    const src = (a.match(/\bsrc\s*=\s*"([^"]*)"/i) || [])[1];
    if (src && !/\bwidth\s*=/i.test(a) && !/\bheight\s*=/i.test(a)) {
      const rel = src.replace(/^(\.\.\/)+/, '');
      const size = imageSize(rel);
      if (size) a += ` width="${size.w}" height="${size.h}"`;
    }
    return `<img${a}>`;
  });
}

/* ================================================================== */
/* Head                                                                */
/* ================================================================== */

function personLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'Person',
    '@id': SITE.origin + '/#person',
    name: SITE.name,
    url: SITE.origin + '/',
    image: SITE.origin + '/' + SITE.profileImage,
    jobTitle: SITE.role,
    email: `mailto:${SITE.email}`,
    telephone: SITE.phoneHref,
    address: { '@type': 'PostalAddress', addressLocality: 'Islamabad', addressCountry: 'PK' },
    knowsAbout: ['Ruby on Rails', 'Hotwire Native', 'REST APIs', 'PostgreSQL', 'Redis', 'Turbo', 'Web performance'],
    sameAs: SITE.sameAs,
  };
}

function headTags({ title, description, keywords, url, image, type, jsonLd, noindex, outFile }) {
  const abs = SITE.origin + url;
  const relImg = image || SITE.ogDefault;
  const absImg = SITE.origin + '/' + relImg.replace(/^\//, '');

  const tags = [
    `<title>${title}</title>`,
    `<meta name="description" content="${esc(description)}">`,
    `<meta name="keywords" content="${esc(keywords || '')}">`,
    `<meta name="author" content="${SITE.name}">`,
    `<link rel="canonical" href="${abs}">`,
    `<meta property="og:type" content="${type || 'website'}">`,
    `<meta property="og:site_name" content="${SITE.name}">`,
    `<meta property="og:locale" content="${SITE.locale}">`,
    `<meta property="og:title" content="${esc(title)}">`,
    `<meta property="og:description" content="${esc(description)}">`,
    `<meta property="og:url" content="${abs}">`,
    `<meta property="og:image" content="${absImg}">`,
    `<meta property="og:image:width" content="1200">`,
    `<meta property="og:image:height" content="630">`,
    `<meta property="og:image:alt" content="${esc(title)}">`,
    `<meta name="twitter:card" content="summary_large_image">`,
    `<meta name="twitter:title" content="${esc(title)}">`,
    `<meta name="twitter:description" content="${esc(description)}">`,
    `<meta name="twitter:image" content="${absImg}">`,
    `<link rel="alternate" type="application/rss+xml" title="${SITE.name} — Blog" href="${up(outFile)}rss.xml">`,
    `<link rel="manifest" href="${up(outFile)}site.webmanifest">`,
    `<meta name="theme-color" content="#0d0d0f">`,
    `<link rel="stylesheet" href="${up(outFile)}assets/css/portfolio.css">`,
  ];
  if (noindex) tags.push(`<meta name="robots" content="noindex, follow">`);
  if (jsonLd && jsonLd.length) {
    const graph = {
      '@context': 'https://schema.org',
      '@graph': jsonLd.map(({ '@context': _drop, ...rest }) => rest),
    };
    tags.push(`<script type="application/ld+json">\n${JSON.stringify(graph, null, 2)}\n\t</script>`);
  }
  return tags;
}

/* ================================================================== */
/* Assemble + write                                                    */
/* ================================================================== */

const written = [];

function write(outFile, html) {
  const full = path.join(ROOT, outFile);
  mkdirSync(path.dirname(full), { recursive: true });
  writeFileSync(full, html);
  written.push(outFile);
  console.log(`  ${outFile.padEnd(48)} ${(Buffer.byteLength(html) / 1024).toFixed(0).padStart(4)} KB`);
}

function assemble({ base, outFile, seo }) {
  const url =
    ROUTE_TO_URL[outFile] ||
    (outFile.endsWith('/index.html') ? '/' + outFile.slice(0, -'index.html'.length) : '/' + outFile);
  let html = base;

  // Remove the theme's placeholder head tags, then add ours.
  html = html.replace(/\n?\s*<meta name="description" content="">/, '');
  html = html.replace(/\n?\s*<meta name="keywords" content="">/, '');
  html = html.replace(/\n?\s*<meta name="author" content="Awaiken">/, '');
  html = html.replace(/\n?\s*<title>[\s\S]*?<\/title>/, '');
  html = html.replace('<html lang="zxx"', '<html lang="en"');

  const tags = headTags({ ...seo, url, outFile });
  html = html.replace('</head>', () => `\n\t<!-- SEO -->\n\t${tags.join('\n\t')}\n</head>`);

  html = normalizeNav(html);
  html = rewritePaths(html, outFile);
  html = fixImages(html);

  write(outFile, html);
}

const orig = (name) => readFileSync(path.join(ORIG, name), 'utf8');
const unused = (name) => readFileSync(path.join(ORIG, 'unused', name), 'utf8');

const posts = JSON.parse(readFileSync(path.join(ORIG, 'posts.json'), 'utf8'));

/* ================================================================== */

console.log('Building from .originals/ — body markup copied verbatim\n');

/* ---------------- Home ---------------- */
assemble({
  base: applyFaqs(applyPricing(orig('index.html'))),
  outFile: 'index.html',
  seo: {
    title: `${SITE.name} — ${SITE.role}`,
    description: 'Freelance Ruby on Rails developer with 3+ years building production web apps, Hotwire Native mobile apps, REST APIs and booking systems.',
    keywords: 'Ruby on Rails developer, freelance Rails developer, Hotwire Native developer, Rails API developer, web development Pakistan',
    jsonLd: [
      personLd(),
      {
        '@context': 'https://schema.org', '@type': 'WebSite', '@id': SITE.origin + '/#website',
        url: SITE.origin + '/', name: SITE.name,
        description: 'Portfolio and blog of Noor Ullah, a freelance Ruby on Rails developer.',
        inLanguage: 'en', publisher: { '@id': SITE.origin + '/#person' },
      },
      {
        '@context': 'https://schema.org', '@type': 'WebPage', '@id': SITE.origin + '/#webpage',
        url: SITE.origin + '/', name: `${SITE.name} — ${SITE.role}`,
        isPartOf: { '@id': SITE.origin + '/#website' }, about: { '@id': SITE.origin + '/#person' }, inLanguage: 'en',
      },
      {
        '@context': 'https://schema.org', '@type': 'ProfilePage', '@id': SITE.origin + '/#profilepage',
        url: SITE.origin + '/', mainEntity: { '@id': SITE.origin + '/#person' }, isPartOf: { '@id': SITE.origin + '/#website' },
      },
      {
        '@context': 'https://schema.org', '@type': 'Service',
        name: 'Ruby on Rails Development', provider: { '@id': SITE.origin + '/#person' }, areaServed: 'Worldwide',
        serviceType: ['Ruby on Rails web application development', 'Hotwire Native mobile app development', 'REST API development', 'Rails performance optimisation'],
      },
      {
        '@context': 'https://schema.org', '@type': 'FAQPage', '@id': SITE.origin + '/#faq',
        mainEntity: FAQS.map(([q, a]) => ({
          '@type': 'Question', name: q.replace(/^Q\d+\.\s*/, ''), acceptedAnswer: { '@type': 'Answer', text: a },
        })),
      },
    ],
  },
});

/* ---------------- Static pages ---------------- */
const crumbs = (...pairs) => ({
  '@context': 'https://schema.org', '@type': 'BreadcrumbList',
  itemListElement: pairs.map(([name, u], i) => ({ '@type': 'ListItem', position: i + 1, name, item: SITE.origin + u })),
});

const STATIC = [
  {
    src: 'about_ab2b6b24ed67.html', outFile: 'about/index.html',
    seo: {
      title: 'About Me — Ruby on Rails Developer in Islamabad | Noor Ullah',
      description: 'Freelance Ruby on Rails developer with 3+ years shipping production web apps, Hotwire Native mobile apps and REST APIs. Based in Islamabad, working worldwide.',
      keywords: 'about Noor Ullah, Rails developer Islamabad, freelance Ruby on Rails developer Pakistan',
      jsonLd: [
        { '@context': 'https://schema.org', '@type': 'ProfilePage', url: SITE.origin + '/about/', mainEntity: { '@id': SITE.origin + '/#person' }, isPartOf: { '@id': SITE.origin + '/#website' } },
        crumbs(['Home', '/'], ['About', '/about/']),
      ],
    },
  },
  {
    src: 'services_327fd057821f.html', outFile: 'services/index.html',
    seo: {
      title: 'Ruby on Rails Development Services | Noor Ullah',
      description: 'Ruby on Rails development services: full-stack Rails web apps, Hotwire Native mobile apps for iOS and Android, REST APIs, design systems and performance work.',
      keywords: 'Ruby on Rails development services, Rails developer for hire, Hotwire Native app development, REST API development, Rails performance optimisation',
      jsonLd: [
        { '@context': 'https://schema.org', '@type': 'Service', name: 'Ruby on Rails Development', provider: { '@id': SITE.origin + '/#person' }, areaServed: 'Worldwide', serviceType: ['Ruby on Rails web application development', 'Hotwire Native mobile app development', 'REST API development', 'Rails performance optimisation', 'Rails code review'] },
        crumbs(['Home', '/'], ['Services', '/services/']),
      ],
    },
  },
  {
    src: 'projects_b6cd068b4053.html', outFile: 'projects/index.html',
    seo: {
      title: 'Ruby on Rails Portfolio — Production Projects | Noor Ullah',
      description: 'Selected Ruby on Rails projects: a Hotwire Native e-commerce app, a travel booking platform, a freight booking site and REST APIs for a safety app.',
      keywords: 'Ruby on Rails portfolio, Rails projects, Hotwire Native app, booking platform, Rails API examples',
      jsonLd: [
        { '@context': 'https://schema.org', '@type': 'CollectionPage', url: SITE.origin + '/projects/', name: 'Ruby on Rails Portfolio', isPartOf: { '@id': SITE.origin + '/#website' } },
        crumbs(['Home', '/'], ['Projects', '/projects/']),
      ],
    },
  },
  {
    src: 'project-single_5fdc0c52313a.html', outFile: 'projects/misrprime/index.html',
    seo: {
      title: 'MisrPrime Case Study — Rails + Hotwire Native | Noor Ullah',
      description: 'How I built MisrPrime: a Rails e-commerce platform with native iOS and Android apps from one Hotwire Native codebase, and the trade-offs involved.',
      keywords: 'Hotwire Native case study, Rails e-commerce, Rails mobile app, MisrPrime, Rails iOS Android app',
      jsonLd: [
        { '@context': 'https://schema.org', '@type': 'CreativeWork', name: 'MisrPrime', headline: 'MisrPrime — Rails e-commerce with Hotwire Native apps', description: 'Case study: building a Rails e-commerce platform with native iOS and Android apps from a single Hotwire Native codebase.', url: SITE.origin + '/projects/misrprime/', author: { '@id': SITE.origin + '/#person' }, inLanguage: 'en' },
        crumbs(['Home', '/'], ['Projects', '/projects/'], ['MisrPrime', '/projects/misrprime/']),
      ],
    },
  },
  {
    src: 'contact_905cd97f5bea.html', outFile: 'contact/index.html',
    seo: {
      title: 'Contact — Hire a Ruby on Rails Developer | Noor Ullah',
      description: 'Get in touch about Ruby on Rails development, Hotwire Native mobile apps or a Rails code review. Email noor102bs@gmail.com or call +92 310 9508764.',
      keywords: 'hire Rails developer, contact Ruby on Rails developer, Rails freelance enquiry',
      jsonLd: [
        { '@context': 'https://schema.org', '@type': 'ContactPage', url: SITE.origin + '/contact/', name: 'Contact', isPartOf: { '@id': SITE.origin + '/#website' }, mainEntity: { '@id': SITE.origin + '/#person' } },
        crumbs(['Home', '/'], ['Contact', '/contact/']),
      ],
    },
  },
  { src: '404_3e7303b6ce4a.html', outFile: '404.html', seo: { title: 'Page Not Found | Noor Ullah', description: 'That page does not exist. Head back to the homepage or explore my Ruby on Rails projects and services.', noindex: true } },
];

for (const p of STATIC) assemble({ base: orig(p.src), outFile: p.outFile, seo: p.seo });

/* ---------------- Blog index ---------------- */
{
  let out = unused('blog_b88d6ef39e72.html');

  const cards = posts.map((post, i) => {
    const delay = i === 0 ? '' : ` data-wow-delay="${([0.2, 0.4, 0.6][i % 3]).toFixed(1)}s"`;
    const cover = post.cover.replace(SITE.origin + '/', '');
    const href = `${post.slug}/index.html`;
    return `<div class="col-xl-4 col-md-6">
                    <!-- Post Item Start -->
                    <div class="post-item wow fadeInUp"${delay}>
                        <div class="post-featured-image">
                            <a href="${href}" data-cursor-text="View">
                                <figure class="image-anime">
                                    <img src="${cover}" alt="${esc(post.title)}">
                                </figure>
                            </a>
                        </div>
                        <div class="post-item-body">
                            <div class="post-item-content">
                                <h2><a href="${href}">${esc(post.title)}</a></h2>
                            </div>
                            <div class="post-item-btn">
                                <a href="${href}" class="readmore-btn">Read More</a>
                            </div>
                        </div>
                    </div>
                    <!-- Post Item End -->
                </div>`;
  }).join('\n                ');

  // Replace the template's run of column-wrapped cards, one column per post.
  const blockRe = /<div class="col-xl-4 col-md-6">\s*<!-- Post Item Start -->[\s\S]*?<!-- Post Item End -->\s*<\/div>/g;
  const blocks = out.match(blockRe);
  if (blocks && blocks.length) {
    const start = out.indexOf(blocks[0]);
    const last = blocks[blocks.length - 1];
    const end = out.indexOf(last, start) + last.length;
    out = out.slice(0, start) + cards + out.slice(end);
  }

  assemble({
    base: out,
    outFile: 'blog/index.html',
    seo: {
      title: 'Ruby on Rails Blog — Engineering Notes & Guides | Noor Ullah',
      description: 'Practical articles on Ruby on Rails development, Hotwire Native mobile apps, Rails performance and hiring freelance developers.',
      keywords: 'Ruby on Rails blog, Rails articles, Hotwire Native guides, Rails performance tips, freelance developer advice',
      jsonLd: [
        {
          '@context': 'https://schema.org', '@type': 'Blog', '@id': SITE.origin + '/blog/#blog',
          url: SITE.origin + '/blog/', name: `${SITE.name} — Ruby on Rails Blog`,
          description: 'Articles on Ruby on Rails development, Hotwire Native apps and Rails performance.',
          inLanguage: 'en', publisher: { '@id': SITE.origin + '/#person' },
          blogPost: posts.map((p) => ({
            '@type': 'BlogPosting', '@id': SITE.origin + '/blog/' + p.slug + '/',
            headline: p.title, url: SITE.origin + '/blog/' + p.slug + '/', datePublished: p.date,
          })),
        },
        crumbs(['Home', '/'], ['Blog', '/blog/']),
      ],
    },
  });
}

/* ---------------- Blog posts ---------------- */
for (const post of posts) {
  const outFile = `blog/${post.slug}/index.html`;
  const cover = post.cover.replace(SITE.origin + '/', '');
  let out = unused('blog-single_4a7c29f5f9af.html');

  // Page-header title, using the theme's own heading markup.
  out = out.replace(/<h1 class="text-anime-style-3"[\s\S]*?<\/h1>/, splitHeading(post.title));

  // Cover image.
  out = out.replace(
    /<div class="post-image">[\s\S]*?<\/div>(\s*)<!-- Post Featured Image Start -->/,
    (all, gap) => `<div class="post-image">\n                        <figure class="image-anime reveal">\n                            <img src="${cover}" alt="${esc(post.title)}">\n                        </figure>\n                    </div>${gap}<!-- Post Featured Image Start -->`
  );

  // Article body, with the theme's WOW reveal classes.
  const body = addWow(cleanBody(post.body));
  out = out.replace(
    /(<div class="post-entry">)[\s\S]*?(<\/div>\s*<!-- Post Entry End -->)/,
    (all, open, close) => `${open}\n                            ${body}\n                        ${close}`
  );

  // Tags.
  const tags = post.keywords.split(',').map((t) => t.trim()).filter(Boolean).slice(0, 6)
    .map((t) => `<a href="../../blog/index.html">${esc(t)}</a>`).join('\n                                            ');
  out = out.replace(/(<span class="tag-links">[\s\S]*?Tags:\s*)[\s\S]*?(<\/span>)/, (all, open, close) => `${open}\n                                            ${tags}\n                                        ${close}`);

  assemble({
    base: out,
    outFile,
    seo: {
      title: `${post.title} | ${SITE.name}`,
      description: post.description,
      keywords: post.keywords,
      image: cover,
      type: 'article',
      jsonLd: [
        {
          '@context': 'https://schema.org', '@type': 'BlogPosting',
          '@id': SITE.origin + '/blog/' + post.slug + '/#article',
          mainEntityOfPage: { '@type': 'WebPage', '@id': SITE.origin + '/blog/' + post.slug + '/' },
          headline: post.title, description: post.description, image: [SITE.origin + '/' + cover],
          datePublished: post.date, dateModified: post.date,
          author: { '@id': SITE.origin + '/#person' }, publisher: { '@id': SITE.origin + '/#person' },
          articleSection: post.category, keywords: post.keywords, inLanguage: 'en',
          isPartOf: { '@id': SITE.origin + '/blog/#blog' },
        },
        crumbs(['Home', '/'], ['Blog', '/blog/'], [post.title, '/blog/' + post.slug + '/']),
      ],
    },
  });
}

console.log(`\n${written.length} pages written.`);