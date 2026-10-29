// paintings.js — the "database" for the gallery.
//
// A hand-picked set of real episodes from Bob Ross's "The Joy of Painting"
// (public reference info, no copyrighted images embedded). Each entry carries
// a color palette that views.js uses to render an inline SVG landscape, so
// the app has zero external image dependencies and still works offline.

const paintings = [
  {
    id: 1,
    title: 'Mountain Hide-Away',
    season: 1,
    episode: 1,
    year: 1983,
    mood: 'Alpine spring. Snow caps, pine forest, mirror lake.',
    palette: { sky: ['#a9c7e8', '#f0e4d4'], mountain: '#5a6b7d', snow: '#f6f6f6', ground: '#2b4a2f', tree: '#1a3620', sun: '#f7d58a' },
  },
  {
    id: 2,
    title: 'Winter at Home',
    season: 1,
    episode: 2,
    year: 1983,
    mood: 'Quiet snowfall over a secluded cabin.',
    palette: { sky: ['#c7cdd8', '#e8ebf0'], mountain: '#7d8794', snow: '#ffffff', ground: '#e4e8ee', tree: '#2a3d2a', sun: '#d8dde6' },
  },
  {
    id: 3,
    title: 'Autumn Mountains',
    season: 1,
    episode: 12,
    year: 1983,
    mood: 'Blazing orange forest below slate-blue peaks.',
    palette: { sky: ['#f4b878', '#f0dcb0'], mountain: '#3f4b5c', snow: '#eef0f3', ground: '#8a4320', tree: '#c76526', sun: '#f8c66b' },
  },
  {
    id: 4,
    title: 'Ebony Sunset',
    season: 2,
    episode: 8,
    year: 1983,
    mood: 'Dark silhouettes over a molten pink sky.',
    palette: { sky: ['#f4a0b4', '#f5c891'], mountain: '#0f0a14', snow: '#2a1a24', ground: '#140912', tree: '#000000', sun: '#f6d678' },
  },
  {
    id: 5,
    title: 'Island in the Wilderness',
    season: 9,
    episode: 13,
    year: 1987,
    mood: 'A lone island crowned with pine, deep blue water.',
    palette: { sky: ['#bcd4e8', '#dfe7ed'], mountain: '#4a6577', snow: '#eef1f5', ground: '#1a3a52', tree: '#1e3a1e', sun: '#f1e3b2' },
  },
  {
    id: 6,
    title: 'Towering Peaks',
    season: 10,
    episode: 13,
    year: 1987,
    mood: 'Sharp granite peaks and a wide valley floor.',
    palette: { sky: ['#b3d0e4', '#e6eef4'], mountain: '#3a4a5c', snow: '#ffffff', ground: '#3f5940', tree: '#1a3620', sun: '#f6e7ad' },
  },
  {
    id: 7,
    title: 'Reflections of Calm',
    season: 14,
    episode: 9,
    year: 1988,
    mood: 'A still lake doubling the sky.',
    palette: { sky: ['#eccfa7', '#b7d2e4'], mountain: '#4a5f73', snow: '#f0ede4', ground: '#223c4e', tree: '#223c23', sun: '#f8c377' },
  },
  {
    id: 8,
    title: 'Blue Winter',
    season: 9,
    episode: 1,
    year: 1987,
    mood: 'Cold blues and whites, a path through the drifts.',
    palette: { sky: ['#a8bfd4', '#dde7ef'], mountain: '#5e7488', snow: '#ffffff', ground: '#dce6ee', tree: '#1f2e38', sun: '#e8edf3' },
  },
  {
    id: 9,
    title: 'Secluded Forest',
    season: 3,
    episode: 4,
    year: 1984,
    mood: 'Dense green canopy, hidden stream.',
    palette: { sky: ['#8fbf86', '#cfe3b7'], mountain: '#2d4a2f', snow: '#5a7a3f', ground: '#1b2d1b', tree: '#0f2110', sun: '#eef1b7' },
  },
  {
    id: 10,
    title: 'Deep Wilderness Home',
    season: 27,
    episode: 6,
    year: 1993,
    mood: 'Log cabin tucked into evergreens.',
    palette: { sky: ['#c0d4e3', '#efe4c8'], mountain: '#5a6a7a', snow: '#f1f4f8', ground: '#2f4a2f', tree: '#1a3220', sun: '#f6cf84' },
  },
  {
    id: 11,
    title: 'Mountain Serenity',
    season: 30,
    episode: 13,
    year: 1994,
    mood: 'Soft dawn, distant peaks fading into mist.',
    palette: { sky: ['#f3cfa8', '#f2e5c7'], mountain: '#6a7e92', snow: '#f0eee2', ground: '#4a6a4a', tree: '#243d24', sun: '#f8d78c' },
  },
  {
    id: 12,
    title: 'A Walk in the Woods',
    season: 1,
    episode: 1,
    year: 1983,
    mood: 'The very first painting from the series.',
    palette: { sky: ['#c6d6b9', '#e4e7cc'], mountain: '#3a4e3a', snow: '#5a6f44', ground: '#2a3920', tree: '#152515', sun: '#f1efa6' },
  },
];

function all() {
  return paintings;
}

function byId(id) {
  const n = Number(id);
  if (!Number.isInteger(n)) return null;
  return paintings.find((p) => p.id === n) || null;
}

module.exports = { all, byId };
