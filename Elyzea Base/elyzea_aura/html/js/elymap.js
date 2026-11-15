'use strict';
/* =========================================================
   CARTE DU TÉLÉPHONE (ElyChat, ElyMeet)
   Fond : la carte 2D d'Elyzea (tuiles de elyzea_hud), déplacement au doigt / à la souris,
   zoom (molette, boutons, double appui), marqueurs HTML (avatars, bulles…) qui gardent leur taille.
   ========================================================= */
const ELYMAP = {
  bounds: { minX: -5661.2, maxX: 6694.0, minY: -4058.5, maxY: 8429.3 },   // même calage que elyzea_hud (Config.CustomMap)
  // image satellite de elyzea_hud (lisible de près comme de loin) ; tuiles possibles : file = 'map2d_{x}_{y}.jpg', cols = rows = 2, tile = 2048
  file: 'map.jpg', cols: 1, rows: 1, tile: 2000,
  base: IS_BROWSER ? '../../elyzea_hud/html/img/' : 'nui://elyzea_hud/html/img/',
};
const EMI = {
  plus: '<path d="M12 5.5v13M5.5 12h13"/>',
  minus: '<path d="M5.5 12h13"/>',
  me: '<circle cx="12" cy="12" r="3.2" fill="currentColor"/><circle cx="12" cy="12" r="7.5"/><path d="M12 2.5v2.5M12 19v2.5M2.5 12H5M19 12h2.5"/>',
};
const emIco = (n) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${EMI[n]}</svg>`;

function elyMap(box, opts = {}) {
  const B = ELYMAP.bounds, TW = ELYMAP.tile * ELYMAP.cols, TH = ELYMAP.tile * ELYMAP.rows;
  const ppmX = TW / (B.maxX - B.minX), ppmY = TH / (B.maxY - B.minY);   // pixels d'image par mètre
  const toU = (x) => (x - B.minX) * ppmX, toV = (y) => (B.maxY - y) * ppmY;
  box.classList.add('emap');
  box.innerHTML = `<div class="emap__tiles">${Array.from({ length: ELYMAP.rows }, (_, y) => Array.from({ length: ELYMAP.cols }, (_, x) =>
    `<img alt="" draggable="false" src="${ELYMAP.base}${ELYMAP.file.replace('{x}', x).replace('{y}', y)}" style="left:${x * ELYMAP.tile}px;top:${y * ELYMAP.tile}px;width:${ELYMAP.tile}px;height:${ELYMAP.tile}px">`).join('')).join('')}</div>
    <div class="emap__marks"></div>
    ${opts.controls === false ? '' : `<div class="emap__ctl"><button data-zin aria-label="${t('Zoomer')}">${emIco('plus')}</button><button data-zout aria-label="${t('Dézoomer')}">${emIco('minus')}</button>${opts.onMe ? `<button data-me aria-label="${t('Ma position')}">${emIco('me')}</button>` : ''}</div>`}`;
  const tiles = box.querySelector('.emap__tiles'), marks = box.querySelector('.emap__marks');
  const M = { cu: toU(opts.x ?? 0), cv: toV(opts.y ?? 0), z: 0.5, list: [], els: new Map(), anim: 0, dead: false };
  const size = () => ({ w: box.clientWidth || 300, h: box.clientHeight || 500 });
  const zFor = (meters) => size().w / (meters * ppmX);
  const zMin = () => Math.max(size().w / TW, size().h / TH) * 0.9;
  const clampZ = (z) => Math.max(zMin(), Math.min(4, z));
  M.z = clampZ(zFor(opts.meters || 1800));

  function project(x, y) {
    const { w, h } = size();
    return [(toU(x) - M.cu) * M.z + w / 2, (toV(y) - M.cv) * M.z + h / 2];
  }
  function render() {
    if (M.dead) return;
    const { w, h } = size();
    tiles.style.transform = `translate(${w / 2 - M.cu * M.z}px, ${h / 2 - M.cv * M.z}px) scale(${M.z})`;
    for (const m of M.list) {
      const el = M.els.get(m.id);
      if (!el) continue;
      const [sx, sy] = project(m.x, m.y);
      el.style.transform = `translate(${sx}px, ${sy}px)`;
      el.style.display = (sx < -80 || sy < -80 || sx > w + 80 || sy > h + 120) ? 'none' : '';
    }
  }
  function setMarkers(list) {
    M.list = list || [];
    const keep = new Set(M.list.map(m => m.id));
    for (const [id, el] of M.els) if (!keep.has(id)) { el.remove(); M.els.delete(id); }
    for (const m of M.list) {
      let el = M.els.get(m.id);
      if (!el) { el = document.createElement('div'); el.className = 'emap__mk'; marks.appendChild(el); M.els.set(m.id, el); }
      if (el._html !== m.html) { el.innerHTML = `<div class="emap__in ${m.cls || ''}">${m.html}</div>`; el._html = m.html; }
      el.style.zIndex = m.z || 1;
      el.onclick = m.onClick ? (e) => { e.stopPropagation(); if (!M.moved) m.onClick(m); } : null;
    }
    render();
  }
  // Aller vers un point (animé)
  function center(x, y, meters, instant) {
    const tu = toU(x), tv = toV(y), tz = meters ? clampZ(zFor(meters)) : M.z;
    cancelAnimationFrame(M.anim);
    if (instant) { M.cu = tu; M.cv = tv; M.z = tz; render(); return; }
    const su = M.cu, sv = M.cv, sz = M.z, t0 = performance.now();
    const step = (now) => {
      const k = Math.min(1, (now - t0) / 420), e = 1 - Math.pow(1 - k, 3);
      M.cu = su + (tu - su) * e; M.cv = sv + (tv - sv) * e; M.z = sz + (tz - sz) * e;
      render();
      if (k < 1 && !M.dead) M.anim = requestAnimationFrame(step);
    };
    M.anim = requestAnimationFrame(step);
  }
  // Cadrer plusieurs points
  function fit(points, pad = 70) {
    if (!points.length) return;
    let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
    for (const p of points) { x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y); }
    const { w, h } = size();
    const mx = Math.max(1400, (x1 - x0)), my = Math.max(1400, (y1 - y0));
    const z = clampZ(Math.min((w - pad * 2) / (mx * ppmX), (h - pad * 2) / (my * ppmY)));
    center((x0 + x1) / 2, (y0 + y1) / 2, w / (z * ppmX));
  }
  function zoomAt(f, px, py) {
    const { w, h } = size();
    const nz = clampZ(M.z * f);
    if (px === undefined) { px = w / 2; py = h / 2; }
    // le point sous le curseur reste sous le curseur
    const u = M.cu + (px - w / 2) / M.z, v = M.cv + (py - h / 2) / M.z;
    M.cu = u - (px - w / 2) / nz; M.cv = v - (py - h / 2) / nz; M.z = nz;
    render();
  }
  // Glisser
  let drag = null;
  box.addEventListener('pointerdown', (e) => {
    if (e.target.closest('.emap__ctl')) return;
    drag = { x: e.clientX, y: e.clientY, cu: M.cu, cv: M.cv }; M.moved = false;
    cancelAnimationFrame(M.anim);
  });
  window.addEventListener('pointermove', M.onMove = (e) => {
    if (!drag) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (Math.abs(dx) + Math.abs(dy) > 4) M.moved = true;
    const r = box.getBoundingClientRect(), k = r.width / (box.clientWidth || r.width);   // zoom du téléphone
    M.cu = drag.cu - dx / k / M.z; M.cv = drag.cv - dy / k / M.z;
    render();
  });
  window.addEventListener('pointerup', M.onUp = () => { drag = null; setTimeout(() => { M.moved = false; }, 0); });
  box.addEventListener('wheel', (e) => {
    e.preventDefault();
    const r = box.getBoundingClientRect(), k = r.width / (box.clientWidth || r.width);
    zoomAt(e.deltaY < 0 ? 1.25 : 0.8, (e.clientX - r.left) / k, (e.clientY - r.top) / k);
  }, { passive: false });
  box.addEventListener('dblclick', (e) => {
    if (e.target.closest('.emap__mk, .emap__ctl')) return;
    const r = box.getBoundingClientRect(), k = r.width / (box.clientWidth || r.width);
    zoomAt(1.8, (e.clientX - r.left) / k, (e.clientY - r.top) / k);
  });
  box.addEventListener('click', (e) => { if (!M.moved && !e.target.closest('.emap__mk, .emap__ctl') && opts.onTap) opts.onTap(); });
  box.querySelector('[data-zin]')?.addEventListener('click', () => zoomAt(1.6));
  box.querySelector('[data-zout]')?.addEventListener('click', () => zoomAt(1 / 1.6));
  box.querySelector('[data-me]')?.addEventListener('click', () => opts.onMe?.());
  const ro = new ResizeObserver(() => render());
  ro.observe(box);
  function destroy() {
    M.dead = true; cancelAnimationFrame(M.anim); ro.disconnect();
    window.removeEventListener('pointermove', M.onMove); window.removeEventListener('pointerup', M.onUp);
  }
  render();
  return { setMarkers, center, fit, zoomAt, destroy, get zoom() { return M.z; } };
}

// Noms des lieux (quartier · rue), demandés au jeu ; mémorisés
const PLACE_CACHE = {};
async function elyPlaces(points) {
  const key = (p) => `${Math.round(p.x / 25)}:${Math.round(p.y / 25)}`;
  const need = points.filter(p => PLACE_CACHE[key(p)] === undefined).slice(0, 60);
  if (need.length) {
    let labels = [];
    if (IS_BROWSER) {
      const Z = ['Vinewood', 'Rockford Hills', 'Del Perro', 'Vespucci Beach', 'Mission Row', 'Pillbox Hill', 'Mirror Park', 'Little Seoul', 'Sandy Shores', 'Paleto Bay'];
      const R = ['Boulevard Del Perro', 'Alta Street', 'Vinewood Boulevard', 'Power Street', 'Route 68', 'San Andreas Avenue'];
      labels = need.map(p => ({ zone: Z[Math.abs(Math.round(p.x / 300 + p.y / 500)) % Z.length], street: R[Math.abs(Math.round(p.x / 200)) % R.length] }));
    } else {
      const r = await post('labelCoords', { points: need.map(p => ({ x: p.x, y: p.y })) });
      labels = (r && r.labels) || [];
    }
    need.forEach((p, i) => { PLACE_CACHE[key(p)] = labels[i] || { zone: '', street: '' }; });
  }
  return points.map(p => PLACE_CACHE[key(p)] || { zone: '', street: '' });
}
const placeText = (l, full) => !l ? '' : (full && l.street && l.zone ? `${l.zone} · ${l.street}` : (l.zone || l.street || ''));
