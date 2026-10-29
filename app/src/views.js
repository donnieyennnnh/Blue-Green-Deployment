// views.js — HTML + inline-SVG rendering for the gallery.
//
// Zero template engine, zero external image URLs. Each painting is drawn as
// an SVG landscape using the palette from paintings.js, so the app has no
// network dependencies at runtime beyond the Prometheus scrape.

// Minimal HTML escape — the data is static today, but hygienic for any
// field that might become user-controlled later.
function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

// Render a painting's palette as an inline SVG landscape. The `uid` makes
// gradient IDs unique when many paintings share a page.
function landscapeSVG(painting, uid) {
  const { sky, mountain, snow, ground, tree, sun } = painting.palette;
  const gradId = `sky-${uid}`;
  return `
<svg viewBox="0 0 400 260" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice" style="display:block;width:100%;height:auto;background:${esc(sky[1])}">
  <defs>
    <linearGradient id="${gradId}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${esc(sky[0])}"/>
      <stop offset="100%" stop-color="${esc(sky[1])}"/>
    </linearGradient>
  </defs>
  <rect width="400" height="180" fill="url(#${gradId})"/>
  <circle cx="310" cy="60" r="28" fill="${esc(sun)}" opacity="0.9"/>
  <polygon points="0,180 70,110 140,160 210,90 280,150 360,100 400,170 400,180" fill="${esc(mountain)}" opacity="0.9"/>
  <polygon points="200,100 215,120 185,120" fill="${esc(snow)}"/>
  <polygon points="355,105 370,125 340,125" fill="${esc(snow)}"/>
  <rect y="175" width="400" height="85" fill="${esc(ground)}"/>
  <polygon points="40,230 55,170 70,230" fill="${esc(tree)}"/>
  <polygon points="100,245 118,180 136,245" fill="${esc(tree)}"/>
  <polygon points="280,240 298,180 316,240" fill="${esc(tree)}"/>
  <polygon points="345,250 360,195 375,250" fill="${esc(tree)}"/>
  <rect y="235" width="400" height="25" fill="#000" opacity="0.08"/>
</svg>`;
}

function layout({ title, color, body }) {
  const colorHex = color === 'green' ? '#2e8b57' : '#1e5fa8';
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8"/>
    <meta name="viewport" content="width=device-width,initial-scale=1"/>
    <title>${esc(title)}</title>
    <style>
      :root { color-scheme: light; }
      * { box-sizing: border-box; }
      body { margin:0; font-family: system-ui, -apple-system, Segoe UI, sans-serif; background:#f6f3ec; color:#222; }
      .badge { background:${colorHex}; color:white; padding:0.75rem 1rem; text-align:center; letter-spacing:0.1em; font-size:0.8rem; }
      .badge code { background:rgba(255,255,255,0.2); padding:0.1rem 0.4rem; border-radius:3px; }
      header.site { padding:2rem 1rem 1rem; text-align:center; }
      header.site h1 { margin:0 0 0.25rem; font-weight:600; letter-spacing:-0.02em; }
      header.site p { margin:0; color:#666; }
      main { max-width:1100px; margin:0 auto; padding:1rem; }
      .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(260px,1fr)); gap:1rem; }
      .card { background:white; border-radius:6px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
      .card .meta { padding:0.75rem 1rem 1rem; }
      .card .title { font-weight:600; margin-bottom:0.2rem; }
      .card .sub { color:#777; font-size:0.85rem; }
      .card .mood { font-style:italic; color:#555; font-size:0.85rem; margin-top:0.4rem; }
      footer { text-align:center; color:#999; font-size:0.8rem; padding:2rem 1rem; }
      footer a { color:#777; }
    </style>
  </head>
  <body>
    <div class="badge">served by the <code>${esc(color)}</code> instance</div>
    ${body}
    <footer>
      Portfolio demo — <a href="/health">/health</a> · <a href="/metrics">/metrics</a>
    </footer>
  </body>
</html>`;
}

function index(paintings, color) {
  const cards = paintings.map((p) => `
    <div class="card">
      ${landscapeSVG(p, p.id)}
      <div class="meta">
        <div class="title">${esc(p.title)}</div>
        <div class="sub">Season ${p.season} · Episode ${p.episode} · ${p.year}</div>
        <div class="mood">${esc(p.mood)}</div>
      </div>
    </div>`).join('');

  const body = `
    <header class="site">
      <h1>The Joy of Deploying</h1>
      <p>A Bob Ross gallery, served with zero downtime.</p>
    </header>
    <main>
      <div class="grid">${cards}</div>
    </main>`;

  return layout({ title: 'The Joy of Deploying', color, body });
}

module.exports = { index };
