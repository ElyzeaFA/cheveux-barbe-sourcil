'use strict';
/* =========================================================
   ELYMEET : rencontres (comme happn), remplace Étincelle
   Inscription en 6 étapes · Croisés (personnes croisées en ville) · Carte des croisements
   · Crushs et messages · Mon profil (édition, préférences, mode invisible).
   Toutes les données viennent du serveur (server/elymeet.lua).
   ========================================================= */
const EM = { ready: false, tok: 0, profile: null, prefill: null, options: null, badges: { messages: 0 }, bolts: 0, map: null, chat: null, draft: null };
const emApi = (name, args = {}) => IS_BROWSER ? EMMock.call(name, args) : api(name, args);
const emGallery = async () => { const r = IS_BROWSER ? await EMMock.call('getGallery') : await api('getGallery'); return (r.photos || []).filter(p => p.type === 'photo' || !p.type); };

const EMIC = {
  feed: '<circle cx="8" cy="8" r="3.2"/><circle cx="16" cy="16" r="3.2"/><path d="M10.5 10.5l3 3"/><path d="M3.5 20.5c.6-2.4 2.3-3.8 4.5-3.8M20.5 3.5c-.6 2.4-2.3 3.8-4.5 3.8"/>',
  map: '<path d="M12 21s7-6.1 7-11.5a7 7 0 0 0-14 0C5 14.9 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  chat: '<path d="M20.5 11.5c0 4.4-3.8 7.5-8.5 7.5-1.2 0-2.3-.2-3.3-.5L4 20l1.3-3.7A7.2 7.2 0 0 1 3.5 11.5C3.5 7.1 7.3 4 12 4s8.5 3.1 8.5 7.5z"/>',
  me: '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
  heart: '<path d="M12 20.5s-7.6-4.6-9.4-9.3C1.3 7.8 3.6 4.5 7 4.5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.4 0 5.7 3.3 4.4 6.7-1.8 4.7-9.4 9.3-9.4 9.3z"/>',
  heartF: '<path d="M12 20.5s-7.6-4.6-9.4-9.3C1.3 7.8 3.6 4.5 7 4.5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.4 0 5.7 3.3 4.4 6.7-1.8 4.7-9.4 9.3-9.4 9.3z" fill="currentColor"/>',
  x: '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
  bolt: '<path d="M13.5 2.5 5 13.5h6l-1 8 8.5-11h-6z" fill="currentColor" stroke="none"/>',
  back: '<path d="m15 5-7 7 7 7"/>',
  next: '<path d="m9 5 7 7-7 7"/>',
  pin: '<path d="M12 21s7-6.1 7-11.5a7 7 0 0 0-14 0C5 14.9 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  cross: '<path d="M4 17h4l8-10h4M4 7h4l2.5 3M14 14l2 3h4"/><path d="m18 5 2 2-2 2M18 15l2 2-2 2"/>',
  send: '<path d="M21 3 10 14"/><path d="M21 3 14.5 21l-4-7.5L3 9.5z"/>',
  plus: '<path d="M12 5.5v13M5.5 12h13"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  job: '<rect x="3.5" y="7.5" width="17" height="12" rx="2"/><path d="M9 7.5V5.5h6v2M3.5 12.5h17"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20.5 20.5-4-4"/>',
  eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>',
  eyeOff: '<path d="M3 3l18 18M10.6 5.7A9.8 9.8 0 0 1 12 5.5C18 5.5 21.5 12 21.5 12a17 17 0 0 1-3.2 3.9M6.2 6.6C3.8 8.3 2.5 12 2.5 12S6 18.5 12 18.5c1.6 0 3-.4 4.2-1"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  spark: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M5.6 18.4l2.8-2.8M15.6 8.4l2.8-2.8"/>',
  sliders: '<path d="M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0"/><circle cx="16" cy="6" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
};
const emIc = (n, cls = '') => `<svg class="emi ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${EMIC[n] || ''}</svg>`;
const emWord = () => `<span class="em-word">Ely<b>Meet</b></span>`;
const emErr = (r) => t(r?.error || 'Action impossible pour le moment.');
function emToast(text) { notify({ app: 'elymeet', title: 'ElyMeet', text }); }
function emAgo(ts) {
  if (!ts) return '';
  const d = Math.max(0, Math.floor(Date.now() / 1000) - ts);
  if (d < 60) return t('à l\'instant');
  if (d < 3600) return t('il y a {n} min', { n: Math.floor(d / 60) });
  if (d < 86400) return t('il y a {n} h', { n: Math.floor(d / 3600) });
  return t('il y a {n} j', { n: Math.floor(d / 86400) });
}
const emTimes = (n) => n > 1 ? t('{n} fois', { n }) : t('1 fois');
const emPh = (url, cls = '') => url ? `<img class="${cls}" src="${esc(url)}" alt="" loading="lazy">` : `<span class="${cls} em-noph">${emIc('me')}</span>`;
const EM_GENDER = { man: 'Homme', woman: 'Femme', other: 'Autre' };
const EM_SEEK = { men: 'Des hommes', women: 'Des femmes', all: 'Tout le monde' };
const emLooking = (id) => t((EM.options?.looking || []).find(l => l.id === id)?.label || '');

/* ---------- Navigation ---------- */
const EM_ROOTS = ['feed', 'map', 'crushes', 'me'];
function emGo(page, params = {}) { openApp('elymeet', Object.assign({ page }, params)); }
function emTab(page) {
  closeSheet(true);
  const first = S.stack.findIndex(e => e.id === 'elymeet');
  if (first >= 0) { S.stack.length = first + 1; S.stack[first].params = { page }; }
  emRender({ page });
}
function emStopMap() { EM.map?.destroy(); EM.map = null; }
function emLeave() { emStopMap(); EM.chat = null; $('.em-match', appView)?.remove(); }

Views.elymeet = (params = {}) => { S.onLeave = emLeave; emRender(params); };

async function emRender(params = {}) {
  const tok = ++EM.tok;
  emStopMap();
  const page = params.page || 'feed';
  if (!EM.ready) {
    emShell(page, loading(), { bare: true });
    const r = await emApi('emInit');
    if (tok !== EM.tok) return;
    if (!r.ok) {
      const why = { unknown: 'ElyMeet n\'est pas chargé sur le serveur (server/elymeet.lua).', server: 'Erreur du serveur : voir la console serveur.', timeout: 'Le serveur ne répond pas, réessaie dans un instant.' }[r.error];
      emShell(page, `<div class="em-retry">${empty(t('ElyMeet indisponible'), why ? t(why) : emErr(r))}<button class="btn em-btn" id="em-retry">${t('Réessayer')}</button></div>`, { bare: true });
      $('#em-retry').onclick = () => emRender(params);
      return;
    }
    EM.profile = r.profile || null; EM.prefill = r.prefill || null; EM.options = r.options; EM.badges = r.badges || EM.badges; EM.bolts = r.bolts || 0;
    EM.ready = true; emSyncBadge();
  }
  if (!EM.profile) return emWelcome();
  const fn = EM_PAGES[page] || EM_PAGES.feed;
  return fn(params, tok);
}

function emShell(page, body, opts = {}) {
  const root = EM_ROOTS.includes(page) ? page : null;
  const nb = (id, ic, label, badge = 0) => `<button class="em-nav__b ${root === id ? 'on' : ''}" data-tab="${id}" aria-label="${t(label)}">${emIc(ic)}<small>${t(label)}</small>${badge > 0 ? `<i class="em-dot">${Math.min(99, badge)}</i>` : ''}</button>`;
  appView.innerHTML = `<div class="em ${opts.bare ? 'em--bare' : ''}" data-page="${page}">
    <main class="em-main ${opts.full ? 'em-main--full' : ''}" id="em-main">${body}</main>
    ${opts.bare || opts.noNav ? '' : `<nav class="em-nav">${nb('feed', 'feed', 'Croisés')}${nb('map', 'map', 'Carte')}${nb('crushes', 'chat', 'Crushs', EM.badges.messages)}${nb('me', 'me', 'Profil')}</nav>`}
  </div>`;
  $$('[data-tab]', appView).forEach(b => b.onclick = () => emTab(b.dataset.tab));
  return $('#em-main');
}
const emTop = (title, right = '', back = true) => `<header class="em-top">${back ? `<button class="em-ib" data-back aria-label="${t('Retour')}">${emIc('back')}</button>` : '<span class="em-top__sp"></span>'}
  <h1 class="em-title">${title}</h1><div class="em-top__r">${right}</div></header>`;
function emSyncBadge() {
  S.emBadge = EM.badges.messages || 0;
  const b = $('.em-nav [data-tab="crushes"]');
  if (b) { b.querySelector('.em-dot')?.remove(); if (S.emBadge > 0) b.insertAdjacentHTML('beforeend', `<i class="em-dot">${Math.min(99, S.emBadge)}</i>`); }
}

/* =========================================================
   INSCRIPTION (6 étapes)
   ========================================================= */
function emWelcome() {
  emShell('feed', `<div class="em-welcome">
      <div class="em-welcome__art"><span class="em-bubble em-bubble--a"></span><span class="em-bubble em-bubble--b"></span><span class="em-path"></span>${solidTile('elymeet', 92)}</div>
      ${emWord()}
      <h2>${t('Retrouve les personnes que tu croises.')}</h2>
      <p>${t('Chaque fois que tu croises quelqu\'un en ville avec ElyMeet, son profil apparaît ici. Un j\'aime réciproque, et c\'est un Crush.')}</p>
      <button class="btn btn--block em-btn" id="em-start">${t('Créer mon profil')}</button>
      <small>${t('Ta position exacte n\'est jamais montrée : seulement le quartier où vous vous êtes croisés.')}</small></div>`, { bare: true });
  $('#em-start').onclick = () => {
    const pf = EM.prefill || {};
    EM.draft = { name: pf.name || '', age: pf.age || '', gender: pf.gender || '', seek: pf.seek || '', looking: '', photos: (pf.photos || []).slice(), interests: [], job: '', bio: pf.bio || '' };
    emStep(0);
  };
}
const EM_STEPS = [
  { id: 'info', title: 'Comment t\'appelles-tu ?', sub: 'C\'est ce que les autres verront sur ton profil.' },
  { id: 'gender', title: 'Tu es…', sub: 'Pour te présenter aux bonnes personnes.' },
  { id: 'seek', title: 'Qui veux-tu rencontrer ?', sub: 'Tu pourras changer ça quand tu veux.' },
  { id: 'photos', title: 'Tes photos', sub: 'Choisis jusqu\'à {n} photos de ta galerie. La première est ta photo principale.' },
  { id: 'interests', title: 'Tes centres d\'intérêt', sub: 'Choisis-en de {a} à {b} : ils s\'afficheront sur ton profil.' },
  { id: 'about', title: 'Encore un mot sur toi', sub: 'Facultatif, mais un profil complet attire plus de crushs.' },
];
// Contenu d'une étape (servi aussi pour modifier une partie du profil)
function emStepBody(id, d, box, onChange) {
  const o = EM.options;
  const chip = (on, val, label, attr = 'data-v') => `<button class="em-chip ${on ? 'on' : ''}" ${attr}="${esc(val)}">${esc(label)}</button>`;
  if (id === 'info') {
    box.innerHTML = `<label class="em-lbl">${t('Prénom')}</label><input class="field em-field" id="em-name" maxlength="30" value="${esc(d.name)}" placeholder="${t('Ton prénom')}">
      <label class="em-lbl">${t('Âge')}</label><div class="em-age"><button class="em-step-btn" data-a="-1">−</button><input class="field em-field" id="em-age" type="number" min="${o.minAge}" max="99" value="${esc(d.age)}" placeholder="${o.minAge}"><button class="em-step-btn" data-a="1">+</button></div>
      <p class="em-hint">${t('{n} ans minimum.', { n: o.minAge })}</p>`;
    $('#em-name', box).oninput = (e) => { d.name = e.target.value; onChange(); };
    $('#em-age', box).oninput = (e) => { d.age = e.target.value; onChange(); };
    $$('[data-a]', box).forEach(b => b.onclick = () => { const v = Math.max(o.minAge, Math.min(99, (+d.age || o.minAge + 4) + +b.dataset.a)); d.age = v; $('#em-age', box).value = v; onChange(); });
  } else if (id === 'gender') {
    box.innerHTML = `<div class="em-big">${Object.entries(EM_GENDER).map(([k, l]) => `<button class="em-bigopt ${d.gender === k ? 'on' : ''}" data-g="${k}"><span>${t(l)}</span><i>${emIc('check')}</i></button>`).join('')}</div>`;
    $$('[data-g]', box).forEach(b => b.onclick = () => { d.gender = b.dataset.g; $$('[data-g]', box).forEach(x => x.classList.toggle('on', x === b)); onChange(); });
  } else if (id === 'seek') {
    box.innerHTML = `<div class="em-big">${Object.entries(EM_SEEK).map(([k, l]) => `<button class="em-bigopt ${d.seek === k ? 'on' : ''}" data-s="${k}"><span>${t(l)}</span><i>${emIc('check')}</i></button>`).join('')}</div>
      <label class="em-lbl">${t('Ce que je cherche')}</label><div class="em-chips">${(o.looking || []).map(l => chip(d.looking === l.id, l.id, t(l.label), 'data-l')).join('')}</div>`;
    $$('[data-s]', box).forEach(b => b.onclick = () => { d.seek = b.dataset.s; $$('[data-s]', box).forEach(x => x.classList.toggle('on', x === b)); onChange(); });
    $$('[data-l]', box).forEach(b => b.onclick = () => { d.looking = b.dataset.l; $$('[data-l]', box).forEach(x => x.classList.toggle('on', x === b)); onChange(); });
  } else if (id === 'photos') {
    const draw = () => {
      const slots = Array.from({ length: o.maxPhotos }, (_, i) => d.photos[i]);
      box.innerHTML = `<div class="em-slots">${slots.map((u, i) => u
        ? `<div class="em-slot em-slot--on ${i === 0 ? 'em-slot--main' : ''}"><img src="${esc(u)}" alt="">${i === 0 ? `<b>${t('Principale')}</b>` : `<button class="em-slot__main" data-main="${i}">${t('En 1re')}</button>`}<button class="em-slot__x" data-rm="${i}" aria-label="${t('Retirer')}">${emIc('close')}</button></div>`
        : `<button class="em-slot" data-add>${emIc('plus')}</button>`).join('')}</div>
        <p class="em-hint">${t('Les photos viennent de ta galerie : prends-en avec l\'appareil photo du téléphone.')}</p>`;
      $$('[data-add]', box).forEach(b => b.onclick = () => emPickPhoto(d.photos, (u) => { d.photos.push(u); draw(); onChange(); }));
      $$('[data-rm]', box).forEach(b => b.onclick = () => { d.photos.splice(+b.dataset.rm, 1); draw(); onChange(); });
      $$('[data-main]', box).forEach(b => b.onclick = () => { const [u] = d.photos.splice(+b.dataset.main, 1); d.photos.unshift(u); draw(); onChange(); });
    };
    draw();
  } else if (id === 'interests') {
    const draw = () => {
      box.innerHTML = `<div class="em-count ${d.interests.length >= o.minInterests ? 'ok' : ''}">${d.interests.length} / ${o.maxInterests}</div>
        ${(o.interests || []).map(c => `<h3 class="em-cat">${esc(t(c.cat))}</h3><div class="em-chips">${c.items.map(it => chip(d.interests.includes(it), it, t(it))).join('')}</div>`).join('')}`;
      $$('[data-v]', box).forEach(b => b.onclick = () => {
        const v = b.dataset.v, i = d.interests.indexOf(v);
        if (i >= 0) d.interests.splice(i, 1); else if (d.interests.length < o.maxInterests) d.interests.push(v); else return emToast(t('{n} centres d\'intérêt maximum.', { n: o.maxInterests }));
        draw(); onChange();
      });
    };
    draw();
  } else if (id === 'about') {
    box.innerHTML = `<label class="em-lbl">${t('Métier')}</label><input class="field em-field" id="em-job" maxlength="40" value="${esc(d.job)}" placeholder="${t('ex. Photographe')}">
      <label class="em-lbl">${t('À propos de moi')}</label><textarea class="field em-field em-bio" id="em-bio" maxlength="${o.bio}" rows="5" placeholder="${t('Ce que j\'aime, ce que je cherche, ce qui me fait rire…')}">${esc(d.bio)}</textarea>
      <p class="em-hint em-hint--r"><span id="em-bn">${d.bio.length}</span> / ${o.bio}</p>`;
    $('#em-job', box).oninput = (e) => { d.job = e.target.value; onChange(); };
    $('#em-bio', box).oninput = (e) => { d.bio = e.target.value; $('#em-bn', box).textContent = d.bio.length; onChange(); };
  }
}
function emStepValid(id, d) {
  const o = EM.options;
  if (id === 'info') return d.name.trim().length >= 2 && +d.age >= o.minAge && +d.age <= 99;
  if (id === 'gender') return !!d.gender;
  if (id === 'seek') return !!d.seek && !!d.looking;
  if (id === 'photos') return d.photos.length > 0;
  if (id === 'interests') return d.interests.length >= o.minInterests;
  return true;
}
function emStep(i) {
  const st = EM_STEPS[i], d = EM.draft, o = EM.options, last = i === EM_STEPS.length - 1;
  emShell('signup', `<div class="em-wiz">
      <header class="em-wiz__top"><button class="em-ib" data-prev aria-label="${t('Retour')}">${emIc('back')}</button>
        <div class="em-prog"><i style="width:${((i + 1) / EM_STEPS.length) * 100}%"></i></div><span class="em-wiz__n">${i + 1}/${EM_STEPS.length}</span></header>
      <div class="em-wiz__body"><h1>${t(st.title)}</h1><p class="em-wiz__sub">${t(st.sub, { n: o.maxPhotos, a: o.minInterests, b: o.maxInterests })}</p><div id="em-step"></div></div>
      <footer class="em-wiz__foot"><p class="error-text" id="em-err"></p><button class="btn btn--block em-btn" id="em-next">${last ? t('Terminer') : t('Continuer')}</button></footer></div>`, { bare: true });
  const btn = $('#em-next');
  const upd = () => { btn.disabled = !emStepValid(st.id, d); };
  emStepBody(st.id, d, $('#em-step'), upd);
  upd();
  $('[data-prev]').onclick = () => i > 0 ? emStep(i - 1) : emWelcome();
  btn.onclick = async () => {
    if (!emStepValid(st.id, d)) return;
    if (!last) return emStep(i + 1);
    btn.disabled = true;
    const r = await emApi('emSaveProfile', Object.assign({}, d, { age: +d.age }));
    btn.disabled = false;
    if (!r.ok) { $('#em-err').textContent = emErr(r); return; }
    EM.profile = r.profile; EM.draft = null;
    emDone();
  };
}
function emDone() {
  const p = EM.profile;
  emShell('signup', `<div class="em-done"><div class="em-done__ph">${emPh(p.photos[0])}<span class="em-done__ok">${emIc('check')}</span></div>
    <h1>${t('Ton profil est prêt, {n} !', { n: esc(p.name) })}</h1>
    <p>${t('Balade-toi en ville avec ton téléphone : les personnes qui te correspondent et que tu croises à moins de {m} m apparaîtront dans « Croisés ».', { m: EM.options.radius })}</p>
    <button class="btn btn--block em-btn" id="em-go">${t('C\'est parti')}</button></div>`, { bare: true });
  $('#em-go').onclick = () => emTab('feed');
}
async function emPickPhoto(current, onPick) {
  const photos = (await emGallery()).filter(p => !current.includes(p.url));
  openSheet(t('Choisir une photo'), photos.length ? `<div class="em-pickgrid">${photos.slice(0, 60).map((p, i) => `<button data-i="${i}"><img src="${esc(p.url)}" alt="" loading="lazy"></button>`).join('')}</div>`
    : `<p class="sheet__text">${t('Aucune autre photo dans ta galerie : prends-en une avec l\'appareil photo.')}</p><button class="btn btn--block em-btn" data-cam>${t('Ouvrir l\'appareil photo')}</button>`, (sh) => {
    $$('[data-i]', sh).forEach(b => b.onclick = () => { closeSheet(); onPick(photos[+b.dataset.i].url); });
    $('[data-cam]', sh)?.addEventListener('click', () => { closeSheet(true); openApp('camera'); });
  });
}

/* =========================================================
   CROISÉS : les personnes croisées en ville
   ========================================================= */
function emCard(p) {
  const state = p.match ? `<span class="em-tag em-tag--crush">${emIc('heartF')}${t('Crush')}</span>`
    : p.bolt ? `<span class="em-tag em-tag--bolt">${emIc('bolt')}${t('Coup de foudre pour toi')}</span>` : '';
  const act = (k, ic, label, on) => `<button class="em-act em-act--${k} ${on ? 'on' : ''}" data-act="${k}" aria-label="${t(label)}">${emIc(ic)}</button>`;
  return `<article class="em-card ${p.bolt && !p.match ? 'em-card--bolt' : ''}" data-id="${p.id}">
    <button class="em-card__ph" data-prof>${emPh(p.photos[0])}<span class="em-card__grad"></span>
      <span class="em-card__top">${state}<span class="em-tag em-tag--glass">${emIc('cross')}${emTimes(p.count)}</span></span>
      <span class="em-card__info"><b>${esc(p.name)}<em>${p.age}</em></b>
        <small>${emIc('pin')}<span data-place="${p.id}">${emAgo(p.ts)}</span></small></span></button>
    <div class="em-card__foot">
      <span class="em-common">${p.common.length ? `${emIc('spark')}${t('{n} en commun', { n: p.common.length })}<em>${esc(p.common.slice(0, 2).map(x => t(x)).join(', '))}</em>` : esc(p.job || emLooking(p.looking))}</span>
      ${p.match ? `<button class="btn em-btn em-btn--sm" data-write>${t('Écrire')}</button>` : `<div class="em-acts">${act('pass', 'x', 'Passer')}${act('like', p.liked === 'like' || p.liked === 'bolt' ? 'heartF' : 'heart', 'J\'aime', p.liked === 'like' || p.liked === 'bolt')}${act('bolt', 'bolt', 'Coup de foudre', p.liked === 'bolt')}</div>`}
    </div></article>`;
}
async function emFeed(params, tok) {
  const main = emShell('feed', `<header class="em-feedtop">${emWord()}<span class="em-bolts" title="${t('Coups de foudre restants aujourd\'hui')}">${emIc('bolt')}<b id="em-bolts">${EM.bolts}</b></span></header><div id="em-feed">${loading()}</div>`);
  const r = await emApi('emFeed');
  if (tok !== EM.tok) return;
  if (!r.ok) { $('#em-feed').innerHTML = empty(t('Fil indisponible'), emErr(r)); return; }
  EM.bolts = r.bolts ?? EM.bolts; $('#em-bolts').textContent = EM.bolts;
  if (r.badges) { EM.badges = r.badges; emSyncBadge(); }
  const people = r.people || [];
  const box = $('#em-feed');
  if (!people.length) {
    box.innerHTML = `<div class="em-empty"><div class="em-empty__art"><span class="em-bubble em-bubble--a"></span><span class="em-bubble em-bubble--b"></span>${emIc('cross')}</div>
      <h2>${t('Personne croisé pour l\'instant')}</h2><p>${t('Balade-toi en ville avec ton téléphone : les personnes qui te correspondent et que tu croises à moins de {m} m apparaîtront ici.', { m: EM.options.radius })}</p></div>`;
    return;
  }
  box.innerHTML = `<p class="em-feedsub">${t('{n} personne(s) croisée(s) ces {d} derniers jours', { n: people.length, d: EM.options.feedDays })}</p>${people.map(emCard).join('')}`;
  emWireCards(box, people);
  emPlaces(box, people);
}
async function emPlaces(box, people) {
  const labels = await elyPlaces(people.filter(p => p.x !== undefined));
  people.filter(p => p.x !== undefined).forEach((p, i) => {
    const el = $(`[data-place="${p.id}"]`, box);
    const pl = placeText(labels[i]);
    if (el) el.textContent = pl ? `${emAgo(p.ts)} · ${pl}` : emAgo(p.ts);
  });
}
function emWireCards(box, people) {
  $$('.em-card', box).forEach(card => {
    const p = people.find(x => x.id === +card.dataset.id);
    $('[data-prof]', card).onclick = () => emGo('profile', { id: p.id });
    $('[data-write]', card)?.addEventListener('click', () => emGo('chat', { match: p.match }));
    $$('[data-act]', card).forEach(b => b.onclick = async () => {
      const kind = b.dataset.act;
      if (kind === 'bolt' && EM.bolts < 1 && p.liked !== 'bolt') return emToast(t('Plus de coup de foudre aujourd\'hui. Reviens demain !'));
      const r = await emApi('emAct', { id: p.id, kind });
      if (!r.ok) return emToast(emErr(r));
      if (r.bolts !== undefined) { EM.bolts = r.bolts; const n = $('#em-bolts'); if (n) n.textContent = r.bolts; }
      if (kind === 'pass') { card.classList.add('em-card--out'); setTimeout(() => card.remove(), 280); return; }
      p.liked = kind;
      if (r.match) { p.match = r.match.id; emCelebrate(r.match); }
      card.outerHTML = emCard(p);
      emWireCards(box, people);
      emPlaces(box, [p]);
    });
  });
}
function emCelebrate(m) {
  const el = document.createElement('div');
  el.className = 'em-match';
  el.innerHTML = `<div class="em-match__in"><h1>${t('C\'est un Crush !')}</h1><p>${t('{n} et toi vous plaisez mutuellement.', { n: esc(m.profile.name) })}</p>
    <div class="em-match__ph"><span>${emPh(m.me?.photos?.[0] || EM.profile?.photos?.[0])}</span><span>${emPh(m.profile.photos[0])}</span><i>${emIc('heartF')}</i></div>
    <button class="btn btn--block em-btn" data-w>${t('Envoyer un message')}</button><button class="btn btn--block em-ghost" data-c>${t('Continuer')}</button></div>`;
  ($('.em', appView) || appView).appendChild(el);
  $('[data-w]', el).onclick = () => { el.remove(); emGo('chat', { match: m.id }); };
  $('[data-c]', el).onclick = () => el.remove();
}

/* ---------- Profil d'une personne ---------- */
async function emProfilePage(params, tok) {
  const main = emShell('profile', loading(), { noNav: true });
  const own = params.own;
  const r = own ? { ok: true, profile: Object.assign({ common: [] }, EM.profile) } : await emApi('emProfile', { id: params.id });
  if (tok !== EM.tok) return;
  if (!r.ok) { main.innerHTML = emTop('') + empty(t('Profil indisponible'), emErr(r)); return; }
  const p = r.profile;
  let idx = 0;
  const common = new Set(p.common || []);
  main.innerHTML = `<div class="em-prof">
    <div class="em-gal">${p.photos.map((u, i) => `<img src="${esc(u)}" alt="" class="${i === 0 ? 'on' : ''}">`).join('')}
      <div class="em-gal__bars">${p.photos.map((_, i) => `<i class="${i === 0 ? 'on' : ''}"></i>`).join('')}</div>
      <button class="em-ib em-ib--glass em-gal__back" data-back aria-label="${t('Retour')}">${emIc('back')}</button>
      <button class="em-gal__l" data-g="-1" aria-label="${t('Précédente')}"></button><button class="em-gal__r" data-g="1" aria-label="${t('Suivante')}"></button>
      <div class="em-gal__info"><h1>${esc(p.name)}<em>${p.age}</em></h1>${p.job ? `<p>${emIc('job')}${esc(p.job)}</p>` : ''}</div></div>
    <div class="em-prof__body">
      ${p.looking ? `<span class="em-looking">${emIc('search')}${esc(emLooking(p.looking))}</span>` : ''}
      ${!own && p.count ? `<section class="em-sec em-crossbox"><div class="em-mini" id="em-mini"></div><div><b>${t('Croisé·e {n}', { n: emTimes(p.count) })}</b><small id="em-pplace">${emAgo(p.ts)}</small></div></section>` : ''}
      ${p.bio ? `<section class="em-sec"><h2>${t('À propos')}</h2><p class="em-bio-txt">${esc(p.bio)}</p></section>` : ''}
      <section class="em-sec"><h2>${t('Centres d\'intérêt')}${common.size ? `<em>${t('{n} en commun', { n: common.size })}</em>` : ''}</h2>
        <div class="em-chips em-chips--ro">${p.interests.map(x => `<span class="em-chip ${common.has(x) ? 'on' : ''}">${esc(t(x))}</span>`).join('')}</div></section>
    </div>
    ${own ? '' : p.match ? `<div class="em-pbar"><button class="btn btn--block em-btn" data-write>${emIc('chat')}${t('Écrire à {n}', { n: esc(p.name) })}</button></div>`
      : `<div class="em-pbar em-acts em-acts--big"><button class="em-act em-act--pass" data-act="pass">${emIc('x')}</button><button class="em-act em-act--like ${p.liked === 'like' || p.liked === 'bolt' ? 'on' : ''}" data-act="like">${emIc(p.liked ? 'heartF' : 'heart')}</button><button class="em-act em-act--bolt ${p.liked === 'bolt' ? 'on' : ''}" data-act="bolt">${emIc('bolt')}</button></div>`}
  </div>`;
  const imgs = $$('.em-gal img', main), bars = $$('.em-gal__bars i', main);
  $$('[data-g]', main).forEach(b => b.onclick = () => { idx = Math.max(0, Math.min(p.photos.length - 1, idx + +b.dataset.g)); imgs.forEach((im, i) => im.classList.toggle('on', i === idx)); bars.forEach((x, i) => x.classList.toggle('on', i <= idx)); });
  $('[data-write]', main)?.addEventListener('click', () => emGo('chat', { match: p.match }));
  $$('[data-act]', main).forEach(b => b.onclick = async () => {
    const kind = b.dataset.act;
    const a = await emApi('emAct', { id: p.id, kind });
    if (!a.ok) return emToast(emErr(a));
    if (a.bolts !== undefined) EM.bolts = a.bolts;
    if (kind === 'pass') { back(); return; }
    await emProfilePage({ id: p.id }, EM.tok);
    if (a.match) emCelebrate(a.match);
  });
  if (!own && p.count && p.x !== undefined) {
    EM.map = elyMap($('#em-mini'), { x: p.x, y: p.y, meters: 900, controls: false });
    EM.map.setMarkers([{ id: 'c', x: p.x, y: p.y, html: '<span class="em-spot em-spot--sm"></span>' }]);
    const [pl] = await elyPlaces([p]);
    const el = $('#em-pplace'); if (el) el.textContent = `${emAgo(p.ts)}${placeText(pl) ? ' · ' + placeText(pl, true) : ''}`;
  }
}

/* =========================================================
   CARTE : lieux de croisement (arrondis)
   ========================================================= */
async function emMapPage(params, tok) {
  const main = emShell('map', `<div class="em-mapwrap"><div class="em-map" id="em-map"></div>
    <header class="em-maptop"><h1>${t('Où vous vous êtes croisés')}</h1></header><div class="em-mapinfo" id="em-mi"></div></div>`, { full: true });
  let data = null;
  EM.map = elyMap($('#em-map'), { meters: 3000, onMe: () => data?.me && EM.map.center(data.me.x, data.me.y, 1500) });
  const r = await emApi('emMap');
  if (tok !== EM.tok || !EM.map) return;
  if (!r.ok) return;
  data = r;
  const spots = r.spots || [];
  const mk = spots.map((s, i) => ({ id: 's' + i, x: s.x, y: s.y, z: 2, cls: 'em-spotmk',
    html: `<span class="em-spot">${emPh(s.people[0]?.photo)}${s.people.length > 1 ? `<b>${s.people.length}</b>` : ''}</span>`, onClick: () => emSpotSheet(s) }));
  if (r.me) mk.push({ id: 'me', x: r.me.x, y: r.me.y, z: 1, html: '<span class="em-memk"></span>' });
  EM.map.setMarkers(mk);
  if (spots.length) EM.map.fit(spots.concat(r.me ? [r.me] : []));
  else if (r.me) EM.map.center(r.me.x, r.me.y, 2500, true);
  else EM.map.center(-300, -900, 4000, true);
  $('#em-mi').innerHTML = spots.length ? `${emIc('cross')}<span>${t('{n} lieu(x) de croisement ces {d} derniers jours. Touche un rond pour voir qui.', { n: spots.length, d: EM.options.feedDays })}</span>`
    : `${emIc('cross')}<span>${t('Aucun croisement pour l\'instant : les lieux où tu croises quelqu\'un apparaîtront ici.')}</span>`;
}
async function emSpotSheet(s) {
  const [pl] = await elyPlaces([s]);
  openSheet(placeText(pl, true) || t('Lieu de croisement'), `<div class="em-spotlist">${s.people.map(p => `<button class="em-li" data-id="${p.id}">${emPh(p.photo, 'em-li__ph')}<span><b>${esc(p.name)}, ${p.age}</b><small>${emAgo(p.ts)} · ${emTimes(p.count)}</small></span>${emIc('next')}</button>`).join('')}</div>`, (sh) => {
    $$('[data-id]', sh).forEach(b => b.onclick = () => { closeSheet(true); emGo('profile', { id: +b.dataset.id }); });
  });
}

/* =========================================================
   CRUSHS ET MESSAGES
   ========================================================= */
async function emCrushes(params, tok) {
  const main = emShell('crushes', `${emTop(t('Crushs'), '', false)}<div id="em-cl">${loading()}</div>`);
  const r = await emApi('emMatches');
  if (tok !== EM.tok) return;
  if (r.badges) { EM.badges = r.badges; emSyncBadge(); }
  const list = r.matches || [];
  const fresh = list.filter(m => m.fresh), convs = list.filter(m => !m.fresh);
  const box = $('#em-cl');
  if (!list.length) {
    box.innerHTML = `<div class="em-empty"><div class="em-empty__art">${emIc('heartF')}</div><h2>${t('Pas encore de crush')}</h2><p>${t('Aime les personnes que tu croises : si c\'est réciproque, c\'est un Crush et vous pouvez discuter.')}</p></div>`;
    return;
  }
  box.innerHTML = `${fresh.length ? `<h2 class="em-h2">${t('Nouveaux crushs')}</h2><div class="em-fresh">${fresh.map(m => `<button class="em-fresh__i" data-m="${m.match}">${emPh(m.photo)}<b>${esc(m.name)}</b></button>`).join('')}</div>` : ''}
    ${convs.length ? `<h2 class="em-h2">${t('Messages')}</h2>${convs.map(m => `<button class="em-conv ${m.unread ? 'em-conv--new' : ''}" data-m="${m.match}">${emPh(m.photo, 'em-conv__ph')}
      <span class="em-conv__t"><b>${esc(m.name)}</b><small>${m.mine ? t('Vous : ') : ''}${esc(m.last || '')}</small></span><span class="em-conv__r"><small>${emAgo(m.ts)}</small>${m.unread ? `<i class="em-dot em-dot--in">${m.unread}</i>` : ''}</span></button>`).join('')}` : ''}`;
  $$('[data-m]', box).forEach(b => b.onclick = () => emGo('chat', { match: +b.dataset.m }));
}
async function emChat(params, tok) {
  EM.chat = params.match;
  const main = emShell('chat', `${emTop('', `<button class="em-ib" data-more aria-label="${t('Options')}">${emIc('sliders')}</button>`)}<div class="em-thread" id="em-th">${loading()}</div>
    <form class="em-compose" id="em-f"><input class="field" id="em-msg" maxlength="${EM.options.message}" autocomplete="off" placeholder="${t('Écris un message…')}"><button class="em-send" aria-label="${t('Envoyer')}">${emIc('send')}</button></form>`, { noNav: true });
  const r = await emApi('emMessages', { match: params.match });
  if (tok !== EM.tok) return;
  if (!r.ok) { $('#em-th').innerHTML = empty(t('Conversation indisponible'), emErr(r)); return; }
  if (r.badges) { EM.badges = r.badges; emSyncBadge(); }
  const p = r.profile, items = r.items || [];
  $('.em-title', main).innerHTML = `<button class="em-chathead" data-prof>${emPh(p?.photos?.[0], 'em-chathead__ph')}<b>${esc(p?.name || '')}</b></button>`;
  $('[data-prof]', main).onclick = () => p && emGo('profile', { id: p.id });
  $('[data-more]', main).onclick = () => confirmSheet(t('Ne plus être en crush ?'), t('La conversation avec {n} sera supprimée et vous ne vous verrez plus.', { n: esc(p?.name || '') }), t('Retirer le crush'), async () => {
    const u = await emApi('emUnmatch', { match: params.match }); if (u.ok) { emToast(t('Crush retiré.')); emTab('crushes'); }
  });
  const draw = () => {
    const box = $('#em-th');
    if (!box) return;
    box.innerHTML = items.length ? items.map(m => `<div class="em-bub em-bub--${m.mine ? 'me' : 'them'}">${esc(m.body)}<small>${emAgo(m.ts)}</small></div>`).join('')
      : `<div class="em-thread__empty">${emPh(p?.photos?.[0], 'em-thread__ph')}<p>${t('Vous êtes en crush avec {n} !', { n: esc(p?.name || '') })}</p>${p?.common?.length ? `<small>${t('Vous aimez tous les deux : {l}', { l: esc(p.common.slice(0, 3).map(x => t(x)).join(', ')) })}</small>` : ''}</div>`;
    box.scrollTop = box.scrollHeight;
  };
  EM.chatItems = items; EM.chatDraw = draw;
  draw();
  $('#em-f').onsubmit = async (e) => {
    e.preventDefault();
    const inp = $('#em-msg'), body = inp.value.trim();
    if (!body) return;
    inp.value = '';
    const s = await emApi('emSend', { match: params.match, body });
    if (s.ok) { items.push(s.item); draw(); } else { emToast(emErr(s)); inp.value = body; }
  };
}

/* =========================================================
   MON PROFIL : aperçu, modifier chaque partie, préférences
   ========================================================= */
function emMe() {
  const p = EM.profile, o = EM.options;
  const filled = [p.photos.length >= 3, p.bio, p.job, p.interests.length >= 5, p.looking].filter(Boolean).length;
  const pct = Math.round(((filled + 1) / 6) * 100);
  const row = (k, ic, title, val) => `<button class="em-li" data-edit="${k}">${emIc(ic)}<span><b>${t(title)}</b><small>${val}</small></span>${emIc('next')}</button>`;
  const main = emShell('me', `${emTop(t('Mon profil'), '', false)}
    <div class="em-me">
      <button class="em-me__card" data-preview>${emPh(p.photos[0])}<span class="em-card__grad"></span><span class="em-card__info"><b>${esc(p.name)}<em>${p.age}</em></b><small>${emIc('eye')}${t('Voir mon profil')}</small></span></button>
      <div class="em-meter"><div><b>${t('Profil complété à {n} %', { n: pct })}</b><small>${pct < 100 ? t('Ajoute des photos, une bio et ton métier pour plus de crushs.') : t('Profil complet !')}</small></div><span class="em-ring" style="--p:${pct}"><b>${pct}</b></span></div>
      <div class="em-list">
        ${row('photos', 'plus', 'Photos', t('{n} / {m}', { n: p.photos.length, m: o.maxPhotos }))}
        ${row('info', 'me', 'Prénom et âge', `${esc(p.name)}, ${p.age} · ${t(EM_GENDER[p.gender] || '')}`)}
        ${row('seek', 'search', 'Je cherche', `${t(EM_SEEK[p.seek] || '')} · ${esc(emLooking(p.looking))}`)}
        ${row('interests', 'spark', 'Centres d\'intérêt', esc(p.interests.slice(0, 3).map(x => t(x)).join(', ')) + (p.interests.length > 3 ? ` +${p.interests.length - 3}` : ''))}
        ${row('about', 'edit', 'Métier et bio', esc(p.job || t('À compléter')))}
      </div>
      <h2 class="em-h2">${t('Préférences')}</h2>
      <div class="em-list em-prefs">
        <div class="em-pref"><span><b>${t('Âge')}</b><small id="em-agel">${p.ageMin} – ${p.ageMax} ${t('ans')}</small></span>
          <div class="em-range"><input type="range" id="em-amin" min="${o.minAge}" max="99" value="${p.ageMin}"><input type="range" id="em-amax" min="${o.minAge}" max="99" value="${p.ageMax}"></div></div>
        <button class="em-pref em-pref--tg" data-vis><span><b>${t('Mode invisible')}</b><small>${t('Tu n\'es plus croisé·e et tu n\'apparais plus chez les autres.')}</small></span><i class="em-switch ${p.visible ? '' : 'on'}"></i></button>
      </div></div>`);
  $('[data-preview]', main).onclick = () => emGo('profile', { own: true });
  $$('[data-edit]', main).forEach(b => b.onclick = () => emGo('edit', { part: b.dataset.edit }));
  const amin = $('#em-amin'), amax = $('#em-amax');
  let saveT;
  const onAge = (e) => {
    let a = +amin.value, b = +amax.value;
    if (a > b) { if (e.target === amin) b = a; else a = b; amin.value = a; amax.value = b; }
    $('#em-agel').textContent = `${a} – ${b} ${t('ans')}`;
    clearTimeout(saveT);
    saveT = setTimeout(async () => { const r = await emApi('emSettings', { ageMin: a, ageMax: b }); if (r.ok) { p.ageMin = r.ageMin; p.ageMax = r.ageMax; } }, 450);
  };
  amin.oninput = onAge; amax.oninput = onAge;
  $('[data-vis]', main).onclick = async () => {
    const r = await emApi('emSettings', { visible: !p.visible });
    if (!r.ok) return emToast(emErr(r));
    p.visible = r.visible;
    $('[data-vis] .em-switch', main).classList.toggle('on', !p.visible);
    emToast(p.visible ? t('Tu es de nouveau visible.') : t('Mode invisible activé.'));
  };
}
function emEdit(params) {
  const part = params.part, st = EM_STEPS.find(s => s.id === part) || EM_STEPS[0], p = EM.profile, o = EM.options;
  const d = { name: p.name, age: p.age, gender: p.gender, seek: p.seek, looking: p.looking, photos: p.photos.slice(), interests: p.interests.slice(), job: p.job, bio: p.bio };
  const main = emShell('edit', `${emTop(t(st.title))}<div class="em-pad"><p class="em-wiz__sub">${t(st.sub, { n: o.maxPhotos, a: o.minInterests, b: o.maxInterests })}</p><div id="em-step"></div></div>
    <footer class="em-wiz__foot"><p class="error-text" id="em-err"></p><button class="btn btn--block em-btn" id="em-save">${t('Enregistrer')}</button></footer>`, { noNav: true });
  const btn = $('#em-save');
  const upd = () => { btn.disabled = !emStepValid(st.id, d); };
  emStepBody(st.id, d, $('#em-step'), upd);
  upd();
  btn.onclick = async () => {
    btn.disabled = true;
    const r = await emApi('emSaveProfile', Object.assign({}, d, { age: +d.age }));
    btn.disabled = false;
    if (!r.ok) { $('#em-err', main).textContent = emErr(r); return; }
    EM.profile = r.profile; emToast(t('Profil enregistré.')); back();
  };
}

const EM_PAGES = { feed: emFeed, map: emMapPage, crushes: emCrushes, me: emMe, profile: emProfilePage, chat: emChat, edit: emEdit };

/* ---------- Événements en direct (serveur → téléphone) ---------- */
function emPush(d) {
  const cur = S.stack[S.stack.length - 1];
  const here = S.open && S.currentApp === 'elymeet' && cur?.id === 'elymeet';
  if (d.type === 'message' && !(here && cur.params?.page === 'chat' && EM.chat === d.match)) { EM.badges.messages = (EM.badges.messages || 0) + 1; emSyncBadge(); }
  if (!here || $('.em-match', appView)) return;
  const page = cur.params?.page || 'feed';
  if (d.type === 'message' && page === 'chat' && EM.chat === d.match && EM.chatItems) { EM.chatItems.push(d.item); EM.chatDraw?.(); emApi('emMessages', { match: d.match }); return; }
  if (d.type === 'message' && page === 'crushes') emRender({ page: 'crushes' });
  if ((d.type === 'crossed' || d.type === 'bolt') && page === 'feed') emRender({ page: 'feed' });
  if (d.type === 'match' && page === 'crushes') emRender({ page: 'crushes' });
}

/* ---------- Aperçu navigateur (hors FiveM) : données de démonstration en mémoire ---------- */
const EMMock = (() => {
  const now = () => Math.floor(Date.now() / 1000);
  const img = (h, txt = '') => 'data:image/svg+xml;utf8,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="hsl(${h},70%,66%)"/><stop offset="1" stop-color="hsl(${(h + 50) % 360},60%,32%)"/></linearGradient></defs><rect width="600" height="800" fill="url(#g)"/><circle cx="300" cy="300" r="120" fill="rgba(255,255,255,.4)"/><path d="M110 800c10-170 90-260 190-260s180 90 190 260z" fill="rgba(255,255,255,.4)"/><text x="30" y="770" font-family="sans-serif" font-size="34" fill="#fff">${txt}</text></svg>`);
  const gallery = [img(10, 'Moi 1'), img(200, 'Moi 2'), img(280, 'Moi 3'), img(120, 'Plage'), img(330, 'Soirée')].map((u, i) => ({ id: i + 1, url: u, type: 'photo' }));
  const P = [
    { id: 2, name: 'Malik', age: 27, gender: 'man', looking: 'serious', photos: [img(20, 'Malik'), img(40, 'Malik 2')], interests: ['Cuisine', 'Musique', 'Voitures', 'Boxe', 'Voyages'], bio: 'Cuisinier le jour, DJ la nuit. Je connais tous les food trucks de Los Santos.', job: 'Chef cuisinier', count: 4, ts: now() - 700, x: -560, y: -380, liked: null, bolt: true },
    { id: 3, name: 'Sarah', age: 24, gender: 'woman', looking: 'dating', photos: [img(330, 'Sarah')], interests: ['Photographie', 'Surf', 'Plage', 'Art'], bio: 'Toujours un appareil photo à la main.', job: 'Photographe', count: 1, ts: now() - 3600 * 3, x: -1340, y: -1490, liked: null },
    { id: 4, name: 'Inès', age: 29, gender: 'woman', looking: 'friends', photos: [img(160, 'Inès'), img(170, 'Inès 2'), img(180, 'Inès 3')], interests: ['Running', 'Yoga', 'Lecture', 'Voyages', 'Cuisine'], bio: '', job: 'Infirmière', count: 2, ts: now() - 86400, x: -560, y: -380, liked: 'like', match: 9 },
  ];
  const D = { profile: null, matches: { 9: { id: 9, with: 4, msgs: [{ id: 1, mine: false, body: 'Salut ! On s\'est croisés à Pillbox ?', ts: now() - 5000 }] } }, bolts: 1 };
  const common = (x) => D.profile ? x.interests.filter(i => D.profile.interests.includes(i)) : [];
  const pub = (x) => Object.assign({}, x, { common: common(x) });
  return {
    call(n, a = {}) {
      if (n === 'getGallery') return { ok: true, photos: gallery };
      if (n === 'emInit') return { ok: true, profile: D.profile, prefill: D.profile ? null : { name: 'Léna', age: 26, gender: 'woman', seek: null, bio: '', photos: [gallery[0].url] }, badges: { messages: 1 }, bolts: D.bolts,
        options: { minAge: 18, maxPhotos: 6, minInterests: 3, maxInterests: 10, bio: 300, message: 500, radius: 60, feedDays: 14,
          looking: [{ id: 'serious', label: 'Une relation sérieuse' }, { id: 'dating', label: 'Des rencontres' }, { id: 'friends', label: 'De nouveaux amis' }, { id: 'unsure', label: 'Je ne sais pas encore' }],
          interests: [{ cat: 'Sorties', items: ['Restaurants', 'Bars', 'Clubs', 'Cinéma', 'Concerts'] }, { cat: 'Sport', items: ['Salle de sport', 'Running', 'Boxe', 'Surf', 'Yoga'] }, { cat: 'Culture', items: ['Musique', 'Lecture', 'Photographie', 'Art', 'Séries'] }, { cat: 'Style de vie', items: ['Cuisine', 'Voyages', 'Plage', 'Voitures', 'Animaux'] }] } };
      if (n === 'emSaveProfile') {
        if (!a.photos?.length) return { ok: false, error: 'Ajoute au moins une photo de ta galerie' };
        D.profile = Object.assign({ id: 1, ageMin: 18, ageMax: 40, visible: true }, D.profile || {}, { name: a.name, age: a.age, gender: a.gender, seek: a.seek, looking: a.looking, photos: a.photos, interests: a.interests, job: a.job || '', bio: a.bio || '' });
        return { ok: true, profile: D.profile };
      }
      if (n === 'emSettings') { Object.assign(D.profile, a.ageMin ? { ageMin: a.ageMin, ageMax: a.ageMax } : {}, a.visible !== undefined ? { visible: a.visible } : {}); return { ok: true, ageMin: D.profile.ageMin, ageMax: D.profile.ageMax, seek: D.profile.seek, visible: D.profile.visible }; }
      if (n === 'emFeed') return { ok: true, people: P.filter(x => x.liked !== 'pass').map(pub).sort((x, y) => (y.bolt ? 1 : 0) - (x.bolt ? 1 : 0) || y.ts - x.ts), bolts: D.bolts, badges: { messages: 1 } };
      if (n === 'emProfile') { const x = P.find(y => y.id === a.id); return x ? { ok: true, profile: pub(x) } : { ok: false, error: 'Profil introuvable' }; }
      if (n === 'emAct') {
        const x = P.find(y => y.id === a.id); if (!x) return { ok: false };
        if (a.kind === 'bolt') { if (D.bolts < 1) return { ok: false, error: 'Plus de coup de foudre aujourd\'hui' }; D.bolts--; }
        x.liked = a.kind;
        if (a.kind !== 'pass' && x.bolt) { x.match = 10; D.matches[10] = { id: 10, with: x.id, msgs: [] }; return { ok: true, match: { id: 10, profile: pub(x), me: D.profile }, bolts: D.bolts }; }
        return { ok: true, bolts: D.bolts };
      }
      if (n === 'emMap') {
        const spots = {};
        P.filter(x => x.liked !== 'pass').forEach(x => { const k = x.x + ':' + x.y; (spots[k] = spots[k] || { x: x.x, y: x.y, people: [] }).people.push({ id: x.id, name: x.name, age: x.age, photo: x.photos[0], count: x.count, ts: x.ts }); });
        return { ok: true, spots: Object.values(spots), me: { x: -640, y: -260 } };
      }
      if (n === 'emMatches') return { ok: true, badges: { messages: 1 }, matches: Object.values(D.matches).map(m => { const x = P.find(y => y.id === m.with); const l = m.msgs[m.msgs.length - 1]; return { match: m.id, id: x.id, name: x.name, age: x.age, photo: x.photos[0], last: l?.body, mine: l?.mine, ts: l?.ts || now(), unread: l && !l.mine ? 1 : 0, fresh: !l }; }) };
      if (n === 'emMessages') { const m = D.matches[a.match]; if (!m) return { ok: false, error: 'Conversation introuvable' }; return { ok: true, profile: pub(P.find(y => y.id === m.with)), items: m.msgs.slice(), badges: { messages: 0 } }; }
      if (n === 'emSend') { const m = D.matches[a.match]; const it = { id: Date.now(), mine: true, body: a.body, ts: now() }; m.msgs.push(it); return { ok: true, item: it }; }
      if (n === 'emUnmatch') { delete D.matches[a.match]; return { ok: true }; }
      return { ok: true };
    },
  };
})();
