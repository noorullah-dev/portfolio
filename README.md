# Noor Ullah — Ruby on Rails Developer

A freelance developer's portfolio and blog. **Plain HTML.** No framework, no
build step, no Node.js required.

Open `index.html` in your browser, edit it, save, refresh. That's the whole
workflow. Upload the folder to any host and it goes live.

Live URL: <https://noorkhan.vercel.app>

---

## Editing

Every page is a real `.html` file. Change the text, save, done.

| Page | File |
| --- | --- |
| Home | `index.html` |
| About | `about/index.html` |
| Services | `services/index.html` |
| Projects | `projects/index.html` |
| MisrPrime case study | `projects/misrprime/index.html` |
| Contact | `contact/index.html` |
| Blog index | `blog/index.html` |
| A blog post | `blog/<post-slug>/index.html` |
| Not-found page | `404.html` |

Each folder has an `index.html` so the URL stays clean (`/about/`). Asset
paths are relative, which is why subpages use `../../assets/…` — keep that
pattern if you move a file to a different depth.

### Adding a blog post

1. Copy an existing post folder, e.g. `blog/ruby-on-rails-vs-django/` →
   `blog/my-new-post/`
2. In the copy, update these four places:
   - `<title>` — the post title, then ` | Noor Ullah`
   - `<meta name="description">`
   - `<link rel="canonical">` and `<meta property="og:url">` — full URL
   - `"headline"`, `"url"` and `"datePublished"` in the JSON-LD
3. Point the cover image at an existing one, or add a new file to
   `assets/images/blog/` and reference it in `og:image`.
4. Add the post to `blog/index.html` so it appears in the list.
5. Add it to `rss.xml` and `sitemap-0.xml`.
6. Run `node tools/check-site.mjs` (see below).

## Checking your work

```sh
node tools/check-site.mjs
```

No install needed — it uses only Node's standard library. It walks every
page, confirms every local link and image actually exists on disk, and
checks the things that break when a file is hand-edited: missing or
duplicated `h1`, title and description length, `canonical` matching the
page's real path, valid JSON-LD, images missing `alt`, and pages that
should be in the sitemap but aren't.

Regenerate the blog cover images after adding a post:

```sh
npm install sharp
node tools/generate-og-images.mjs
```

This reads each published post's title and category and rewrites the
1200×630 cards in `assets/images/blog/`.

## What's in here

```
index.html          about/          services/
projects/           projects/misrprime/
contact/            blog/           blog/<7 posts>/
404.html
assets/
  css/      theme stylesheets + portfolio.css (accessibility, blog styles)
  js/       theme scripts (GSAP, SplitText, WOW, Swiper, jQuery, …)
  images/   photos, icons, blog covers
  fonts/    typefaces
  media/    résumé PDF
robots.txt  rss.xml  sitemap-0.xml  site.webmanifest
tools/      check-site.mjs, build-html.mjs, generate-og-images.mjs
.originals/ pristine copy of the original theme markup
vercel.json redirects and cache headers
```

**The `.html` files are what you edit.** `.originals/` is a read-only copy of
the template exactly as it was downloaded, kept only so the design can be
restored or audited. `tools/build-html.mjs` regenerates the site from it — but
you do not need it, and running it will overwrite your edits to the page
files. Only reach for it if you want to reset a page back to the original
template.

`assets/css/portfolio.css` is the only stylesheet added on top of the
original theme. It holds the skip link, screen-reader helpers, reduced-motion
support, and the blog styles. Everything else is the theme's original CSS,
untouched.

## The design

The visual design is the original Weblance/Awaiken template, unchanged. The
page markup is the template's own markup, copied through verbatim — same
sections in the same order, same theme classes, same GSAP animations
(`text-anime-style-3` headings, `split-line` per-character spans, WOW.js
reveals, Swiper sliders, MagicCursor, parallax). The `<!-- Section Start -->`
comments are all still in place, so you can find anything quickly with a text
search.

If you ever need to check that a page still matches the template:

```sh
grep -c 'class="split-line"' index.html          # animated headings
grep -c 'visibility: visible' index.html         # baked WOW reveal states
grep -c '<!--' index.html                       # section markers
```

Only invisible things were changed:

- relative asset paths and clean URLs
- `width`/`height` on images, to stop the page jumping while loading
- `alt` text on every image
- `<html lang="en">` instead of the template's `lang="zxx"`
- the contact form now posts to formsubmit.co and emails submissions to the
  address in its `action`

The pricing cards keep the original design but describe engagement models
instead of the template's placeholder `$49 / $149 / $249` figures. The FAQ
accordion keeps the original Bootstrap markup and is filled with real
questions about working with me. Everything else is the template's own copy.

## SEO

Already set up, and `tools/check-site.mjs` keeps it honest:

- unique `<title>` and meta description on all 15 pages
- canonical URLs, Open Graph and Twitter cards
- JSON-LD structured data: `Person`, `WebSite`, `WebPage`, `ProfilePage`,
  `Service`, `FAQPage`, `BreadcrumbList`, `BlogPosting`, `CreativeWork`
- `sitemap-0.xml` covering all 14 indexable pages
- `robots.txt`, RSS feed at `rss.xml`, web manifest
- redirects in `vercel.json` from the old hashed filenames

**One thing to verify before launch:** the copy says "3+ years of
experience". That came from the original site and was not independently
verified. If it needs changing, search for `3+` and `class="counter">3<`
across the `.html` files.

## Deploying

**Vercel** — connect the repository. There's no build command; Vercel serves
the root as static files. `vercel.json` handles the redirects and caching.

**Netlify** — drag the folder onto the Netlify drop. Same result.

**Anywhere else** — upload the folder contents via FTP or the host's file
manager. Nothing needs to run on the server.

If you add a custom domain, search and replace
`https://noorkhan.vercel.app` across the `.html`, `rss.xml`,
`sitemap-0.xml`, `robots.txt` and `site.webmanifest`.