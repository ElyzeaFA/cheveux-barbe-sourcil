'use strict';
/* =========================================================
   ELYCHAT : messagerie photo (comme Snapchat)
   Carte des amis · Chat (snaps + messages éphémères) · Caméra (snap d'une photo de la galerie)
   · Amis (recherche, demandes) · Profil (ElyScore, partage de position).
   Toutes les données viennent du serveur (server/elychat.lua).
   ========================================================= */
const EC = {
  acc: null, ready: false, tok: 0, share: 'off', badges: { snaps: 0, chats: 0, requests: 0 },
  limits: { message: 400, caption: 80, recipients: 15, durations: [3, 5, 10, 0], chatHours: 24, mapRefresh: 15 }, colors: [],
  draft: null, chatWith: null, map: null, mapTimer: 0, viewer: null,
};
const ecApi = (name, args = {}) => IS_BROWSER ? ECMock.call(name, args) : api(name, args);
const ecGallery = async () => { const r = IS_BROWSER ? await ECMock.call('getGallery') : await api('getGallery'); return (r.photos || []).filter(p => p.type === 'photo' || !p.type); };

const ECI = {
  map: '<path d="M9 4.5 3.5 6.8v12.7L9 17.2l6 2.3 5.5-2.3V4.5L15 6.8z"/><path d="M9 4.5v12.7M15 6.8v12.7"/>',
  chat: '<path d="M4 5.5h16v10.5H9.5L5 19.5v-3.5H4z"/>',
  cam: '<path d="M4 7.5h3.2L9 5h6l1.8 2.5H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8.5a1 1 0 0 1 1-1z"/><circle cx="12" cy="13.5" r="3.6"/>',
  friends: '<circle cx="9" cy="8.5" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 5.2a3.5 3.5 0 0 1 0 6.6M18 14.2c2 .9 3.5 3 3.5 5.8"/>',
  me: '<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
  add: '<circle cx="10" cy="8.5" r="3.8"/><path d="M3 20a7 7 0 0 1 14 0M19 7v6M16 10h6"/>',
  back: '<path d="m15 5-7 7 7 7"/>',
  send: '<path d="M21 3 10 14"/><path d="M21 3 14.5 21l-4-7.5L3 9.5z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20.5 20.5-4-4"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  flame: '<path d="M12 21.5c-4.1 0-7-2.9-7-6.8 0-3.2 2.1-5.4 3.6-7.5.3 2 1.3 3.1 2.5 3.5C11 7 12.6 4.4 15.1 2.8c-.3 2.9.8 4.8 2.2 6.5 1.1 1.4 1.7 3 1.7 5.4 0 3.9-2.9 6.8-7 6.8z" fill="currentColor" stroke="none"/>',
  ghost: '<path d="M5 20V10a7 7 0 0 1 14 0v10l-2.4-1.6L14.3 20 12 18.4 9.7 20l-2.3-1.6z"/><circle cx="9.5" cy="10.5" r="1" fill="currentColor"/><circle cx="14.5" cy="10.5" r="1" fill="currentColor"/>',
  pin: '<path d="M12 21s7-6.1 7-11.5a7 7 0 0 0-14 0C5 14.9 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3h.1a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8v.1a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  timer: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2.5M9.5 2.5h5"/>',
  text: '<path d="M5 6.5V5h14v1.5M12 5v14M9 19h6"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  route: '<circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="6" r="2.5"/><path d="M8.5 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.5"/>',
  star: '<path d="m12 3.5 2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z" fill="currentColor" stroke="none"/>',
  save: '<path d="M6.5 3.5h11v17L12 16.5l-5.5 4z"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>',
};
const ecIco = (n, cls = '') => `<svg class="eci ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ECI[n] || ''}</svg>`;
const ecWord = () => `<span class="ec-word">Ely<b>Chat</b></span>`;
const ecErr = (r) => t(r?.error || 'Action impossible pour le moment.');
function ecToast(text) { notify({ app: 'elychat', title: 'ElyChat', text }); }
function ecAv(u, size = 44, ring = false) {
  if (!u) return '';
  const inner = u.avatar ? `<img src="${esc(u.avatar)}" alt="">` : `<b>${esc(initials(u.name || u.u))}</b>`;
  return `<span class="ec-av ${ring ? 'ec-av--ring' : ''}" style="--s:${size}px;--c:${esc(u.color || '#FFD60A')}">${inner}</span>`;
}
function ecAgo(ts) {
  if (!ts) return '';
  const d = Math.max(0, Math.floor(Date.now() / 1000) - ts);
  if (d < 60) return t('à l\'instant');
  if (d < 3600) return t('{n} min', { n: Math.floor(d / 60) });
  if (d < 86400) return t('{n} h', { n: Math.floor(d / 3600) });
  return t('{n} j', { n: Math.floor(d / 86400) });
}
const ecStreak = (n) => n > 0 ? `<span class="ec-streak">${n}${ecIco('flame')}</span>` : '';

/* ---------- Navigation ---------- */
const EC_ROOTS = ['map', 'chats', 'camera', 'friends', 'me'];
function ecGo(page, params = {}) { openApp('elychat', Object.assign({ page }, params)); }
function ecTab(page) {
  closeSheet(true);
  const first = S.stack.findIndex(e => e.id === 'elychat');
  if (first >= 0) { S.stack.length = first + 1; S.stack[first].params = { page }; }
  ecRender({ page });
}
function ecLeave() { ecStopMap(); EC.chatWith = null; ecCloseViewer(); }
function ecStopMap() { clearInterval(EC.mapTimer); EC.mapTimer = 0; EC.map?.destroy(); EC.map = null; }

Views.elychat = (params = {}) => { S.onLeave = ecLeave; ecRender(params); };

async function ecRender(params = {}) {
  const tok = ++EC.tok;
  ecStopMap();
  const page = params.page || 'chats';
  if (!EC.ready) {
    ecShell(page, loading(), { bare: true });
    const r = await ecApi('ecInit');
    if (tok !== EC.tok) return;
    if (!r.ok) {
      const why = { unknown: 'ElyChat n\'est pas chargé sur le serveur (server/elychat.lua).', server: 'Erreur du serveur : voir la console serveur.', timeout: 'Le serveur ne répond pas, réessaie dans un instant.' }[r.error];
      ecShell(page, `<div class="ec-retry">${empty(t('ElyChat indisponible'), why ? t(why) : ecErr(r))}<button class="btn ec-btn" id="ec-retry">${t('Réessayer')}</button></div>`, { bare: true });
      $('#ec-retry').onclick = () => ecRender(params);
      return;
    }
    EC.acc = r.account || null; EC.share = r.share || 'off'; EC.badges = r.badges || EC.badges;
    Object.assign(EC.limits, r.limits || {}); EC.colors = r.colors || []; EC.ready = true;
    ecSyncBadge();
  }
  if (!EC.acc) return ecOnboard();
  const fn = EC_PAGES[page] || EC_PAGES.chats;
  return fn(params, tok);
}

function ecShell(page, body, opts = {}) {
  const root = EC_ROOTS.includes(page) ? page : null;
  const nb = (id, ic, label, badge = 0) => {
    if (id === 'camera') return `<button class="ec-nav__cam" data-tab="camera" aria-label="${t(label)}"><span>${ecIco('cam')}</span></button>`;
    return `<button class="ec-nav__b ${root === id ? 'on' : ''}" data-tab="${id}" aria-label="${t(label)}">${ecIco(ic)}<small>${t(label)}</small>${badge > 0 ? `<i class="ec-dot">${Math.min(99, badge)}</i>` : ''}</button>`;
  };
  appView.innerHTML = `<div class="ec ${opts.dark ? 'ec--dark' : ''} ${opts.bare ? 'ec--bare' : ''}" data-page="${page}">
    <main class="ec-main ${opts.full ? 'ec-main--full' : ''}" id="ec-main">${body}</main>
    ${opts.bare || opts.noNav ? '' : `<nav class="ec-nav">${nb('map', 'map', 'Carte')}${nb('chats', 'chat', 'Chat', EC.badges.snaps + EC.badges.chats)}${nb('camera', 'cam', 'Caméra')}${nb('friends', 'friends', 'Amis', EC.badges.requests)}${nb('me', 'me', 'Profil')}</nav>`}
  </div>`;
  $$('[data-tab]', appView).forEach(b => b.onclick = () => ecTab(b.dataset.tab));
  return $('#ec-main');
}
const ecTop = (title, right = '', left = '') => `<header class="ec-top">${left || `<button class="ec-ib" data-back aria-label="${t('Retour')}">${ecIco('back')}</button>`}
  <h1 class="ec-title">${title}</h1><div class="ec-top__r">${right}</div></header>`;
function ecSyncBadge() {
  S.ecBadge = (EC.badges.snaps || 0) + (EC.badges.chats || 0) + (EC.badges.requests || 0);
  const set = (tab, n) => { const b = $(`.ec-nav [data-tab="${tab}"]`); if (!b) return; b.querySelector('.ec-dot')?.remove(); if (n > 0) b.insertAdjacentHTML('beforeend', `<i class="ec-dot">${Math.min(99, n)}</i>`); };
  set('chats', EC.badges.snaps + EC.badges.chats); set('friends', EC.badges.requests);
}

/* ---------- Création du compte ---------- */
function ecOnboard() {
  let color = EC.colors[0] || '#FFD60A';
  ecShell('chats', `<div class="ec-onboard">
    <div class="ec-onboard__logo">${solidTile('elychat', 86)}</div>
    ${ecWord()}
    <p class="ec-onboard__txt">${t('Envoie des snaps à tes amis, discute et retrouve-les sur la carte.')}</p>
    <div class="ec-form">
      <div class="ec-preview" id="ec-pv"></div>
      <label class="ec-lbl">${t('Nom affiché')}</label>
      <input class="field" id="ec-display" maxlength="30" value="${esc(S.profile?.name || '')}">
      <label class="ec-lbl">${t('Nom d\'utilisateur')}</label>
      <div class="handle-field"><span>@</span><input class="field" id="ec-user" maxlength="20" autocomplete="off" placeholder="${t('ex. lena.duval')}"></div>
      <label class="ec-lbl">${t('Ta couleur')}</label>
      <div class="ec-colors">${EC.colors.map(c => `<button class="ec-color ${c === color ? 'on' : ''}" data-c="${c}" style="--c:${c}" aria-label="${c}"></button>`).join('')}</div>
      <p class="error-text" id="ec-err"></p>
      <button class="btn btn--block ec-btn" id="ec-go">${t('Créer mon compte')}</button>
    </div></div>`, { bare: true });
  const pv = () => { $('#ec-pv').innerHTML = ecAv({ name: $('#ec-display').value || '?', color }, 76, true); };
  pv();
  $('#ec-display').oninput = pv;
  $$('.ec-color').forEach(b => b.onclick = () => { color = b.dataset.c; $$('.ec-color').forEach(x => x.classList.toggle('on', x === b)); pv(); });
  $('#ec-user').oninput = (e) => { e.target.value = e.target.value.toLowerCase().replace(/[^a-z0-9_.]/g, ''); };
  $('#ec-go').onclick = async () => {
    const r = await ecApi('ecCreateAccount', { username: $('#ec-user').value, display: $('#ec-display').value, color });
    if (!r.ok) { $('#ec-err').textContent = ecErr(r); return; }
    EC.acc = r.account; ecRender({ page: 'chats' });
  };
}

/* =========================================================
   CHAT : liste façon Snapchat
   ========================================================= */
function ecStatus(st) {
  if (!st) return `<span class="ec-st ec-st--none">${t('Appuie pour discuter')}</span>`;
  const snap = st.kind === 'snap';
  const color = snap ? 'red' : 'blue';
  const shape = st.dir === 'in' ? (snap ? 'sq' : 'bub') : 'arrow';
  const filled = st.state === 'new' || st.state === 'delivered';
  const label = st.dir === 'in'
    ? (st.state === 'new' ? (snap ? 'Nouveau snap' : 'Nouveau chat') : (snap ? 'Ouvert' : 'Reçu'))
    : (st.state === 'delivered' ? 'Envoyé' : 'Ouvert');
  return `<span class="ec-st ec-st--${color} ${st.state === 'new' ? 'ec-st--new' : ''}"><i class="ec-sh ec-sh--${shape} ${filled ? 'f' : ''}"></i>${t(label)}<em>· ${ecAgo(st.ts)}</em></span>`;
}
async function ecChats(params, tok) {
  const main = ecShell('chats', `${ecTop(t('Chat'), `<button class="ec-ib" data-add aria-label="${t('Ajouter des amis')}">${ecIco('add')}</button>`,
    `<button class="ec-me" data-me>${ecAv(EC.acc, 34)}</button>`)}<div id="ec-list">${loading()}</div>`);
  $('[data-add]', main).onclick = () => ecTab('friends');
  $('[data-me]', main).onclick = () => ecTab('me');
  const r = await ecApi('ecChats');
  if (tok !== EC.tok) return;
  if (r.badges) { EC.badges = r.badges; ecSyncBadge(); }
  const list = r.chats || [];
  const box = $('#ec-list');
  if (!list.length) {
    box.innerHTML = `<div class="ec-pad">${empty(t('Aucune conversation'), t('Ajoute des amis pour leur envoyer des snaps.'), `<button class="btn ec-btn" data-go="friends">${t('Ajouter des amis')}</button>`)}</div>`;
    $('[data-go]', box).onclick = () => ecTab('friends');
    return;
  }
  box.innerHTML = list.map(c => `<div class="ec-row ${c.newSnaps ? 'ec-row--snap' : ''}" data-u="${esc(c.u)}">
      <button class="ec-row__main" data-row>${ecAv(c, 48)}<span class="ec-row__txt"><b>${esc(c.name)}</b>${ecStatus(c.status)}</span></button>
      <span class="ec-row__r">${ecStreak(c.streak)}<button class="ec-ib ec-ib--sm" data-chat aria-label="${t('Discuter')}">${ecIco('chat')}</button></span>
    </div>`).join('');
  $$('.ec-row', box).forEach(row => {
    const c = list.find(x => x.u === row.dataset.u);
    $('[data-row]', row).onclick = () => c.newSnaps ? ecOpenSnap(c) : ecGo('chat', { u: c.u });
    $('[data-chat]', row).onclick = () => ecGo('chat', { u: c.u });
  });
}

/* ---------- Lecteur de snap (vu une seule fois, minuteur) ---------- */
function ecCloseViewer() {
  if (!EC.viewer) return;
  clearInterval(EC.viewer.timer);
  EC.viewer.el.remove();
  EC.viewer = null;
}
async function ecOpenSnap(c) {
  const r = await ecApi('ecOpenSnap', { u: c.u });
  if (!r.ok) { ecToast(ecErr(r)); return; }
  ecCloseViewer();
  const el = document.createElement('div');
  el.className = 'ec-viewer';
  const s = r.snap;
  el.innerHTML = `<img class="ec-viewer__img" src="${esc(s.url)}" alt="">
    <header class="ec-viewer__top">${ecAv(c, 34)}<span><b>${esc(c.name)}</b><small>${ecAgo(s.ts)}</small></span>
      ${s.duration > 0 ? `<svg class="ec-ring" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" class="bg"/><circle cx="18" cy="18" r="15" class="fg" id="ec-ring"/></svg><b class="ec-ring__n" id="ec-ring-n">${s.duration}</b>`
        : `<button class="ec-ib" data-x aria-label="${t('Fermer')}">${ecIco('close')}</button>`}</header>
    ${s.caption ? `<div class="ec-cap">${esc(s.caption)}</div>` : ''}
    ${r.left > 0 ? `<div class="ec-viewer__more">${t('{n} autre(s) snap(s) · appuie pour continuer', { n: r.left })}</div>` : ''}`;
  ($('.ec', appView) || appView).appendChild(el);
  EC.viewer = { el };
  const next = () => {
    ecCloseViewer();
    if (r.left > 0) ecOpenSnap(c);
    else if (S.currentApp === 'elychat') ecRender(S.stack[S.stack.length - 1]?.params || { page: 'chats' });
  };
  el.onclick = (e) => { e.stopPropagation(); next(); };
  if (s.duration > 0) {
    const t0 = Date.now(), total = s.duration * 1000, C = 2 * Math.PI * 15;
    const ring = $('#ec-ring', el); ring.style.strokeDasharray = C;
    EC.viewer.timer = setInterval(() => {
      const k = Math.min(1, (Date.now() - t0) / total);
      ring.style.strokeDashoffset = C * k;
      const n = $('#ec-ring-n', el); if (n) n.textContent = Math.max(0, Math.ceil((total - (Date.now() - t0)) / 1000));
      if (k >= 1) next();
    }, 100);
  }
}

/* ---------- Conversation ---------- */
async function ecChat(params, tok) {
  EC.chatWith = params.u;
  const main = ecShell('chat', `${ecTop('', '')}<div class="ec-thread" id="ec-thread">${loading()}</div>
    <form class="ec-compose" id="ec-form"><button type="button" class="ec-ib ec-compose__cam" data-snap aria-label="${t('Envoyer un snap')}">${ecIco('cam')}</button>
      <input class="field" id="ec-msg" maxlength="${EC.limits.message}" autocomplete="off" placeholder="${t('Envoyer un chat')}">
      <button class="ec-ib ec-compose__send" aria-label="${t('Envoyer')}">${ecIco('send')}</button></form>`, { noNav: true });
  const r = await ecApi('ecChat', { u: params.u });
  if (tok !== EC.tok) return;
  if (!r.ok) { $('#ec-thread').innerHTML = empty(t('Conversation indisponible'), ecErr(r)); return; }
  const u = r.user;
  $('.ec-title', main).innerHTML = `<button class="ec-chathead" data-prof>${ecAv(u, 32)}<span><b>${esc(u.name)}</b><small>@${esc(u.u)}${u.streak ? ` · ${u.streak} ${t('jours')}` : ''}</small></span>${ecStreak(u.streak)}</button>`;
  $('[data-prof]', main).onclick = () => ecFriendSheet(u);
  const items = r.items || [];
  const draw = () => {
    const box = $('#ec-thread');
    if (!box) return;
    if (!items.length) { box.innerHTML = `<div class="ec-thread__empty">${ecAv(u, 64)}<p>${t('Envoie un snap ou un message à {n} !', { n: esc(u.name) })}</p><small>${t('Les messages vus disparaissent après {h} h. Appuie sur un message pour l\'enregistrer.', { h: EC.limits.chatHours })}</small></div>`; return; }
    let html = '', lastWho = null;
    for (const it of items) {
      const who = it.mine ? 'me' : 'them';
      if (who !== lastWho) html += `<div class="ec-who ec-who--${who}">${it.mine ? t('MOI') : esc(u.name.toUpperCase())}</div>`;
      lastWho = who;
      if (it.kind === 'snap') {
        const lbl = it.mine ? (it.opened ? 'Snap ouvert' : 'Snap envoyé') : (it.opened ? 'Snap ouvert' : 'Nouveau snap');
        html += `<div class="ec-ev ec-ev--${who}"><i class="ec-sh ec-sh--${it.mine ? 'arrow' : 'sq'} ${it.opened ? '' : 'f'}"></i>${t(lbl)}<em>${ecAgo(it.ts)}</em></div>`;
      } else {
        html += `<button class="ec-msg ec-msg--${who} ${it.saved ? 'saved' : ''}" data-id="${it.id}">${esc(it.body)}${it.saved ? `<span class="ec-msg__saved">${ecIco('save')}${t('Enregistré')}</span>` : ''}</button>`;
      }
    }
    box.innerHTML = html;
    box.scrollTop = box.scrollHeight;
    $$('.ec-msg', box).forEach(b => b.onclick = async () => {
      const it = items.find(x => x.kind === 'chat' && x.id === +b.dataset.id);
      const s = await ecApi('ecSave', { id: it.id });
      if (s.ok) { it.saved = s.saved; draw(); }
    });
    if (items.some(i => i.kind === 'snap' && !i.mine && !i.opened)) {
      box.insertAdjacentHTML('beforeend', `<button class="btn ec-btn ec-open-snap" data-view>${t('Voir le snap')}</button>`);
      $('[data-view]', box).onclick = () => ecOpenSnap(u);
    }
  };
  EC.chatItems = items; EC.chatDraw = draw;
  draw();
  $('[data-snap]', main).onclick = () => ecGo('camera', { to: u.u });
  $('#ec-form').onsubmit = async (e) => {
    e.preventDefault();
    const inp = $('#ec-msg'), body = inp.value.trim();
    if (!body) return;
    inp.value = '';
    const s = await ecApi('ecSend', { u: u.u, body });
    if (s.ok) { items.push(s.item); draw(); } else { ecToast(ecErr(s)); inp.value = body; }
  };
}

/* =========================================================
   CAMÉRA : snap d'une photo de la galerie (légende, minuteur, destinataires)
   ========================================================= */
async function ecCamera(params, tok) {
  const main = ecShell('camera', `<div class="ec-cam">
      <header class="ec-cam__top"><h1>${t('Nouveau snap')}</h1></header>
      <button class="ec-cam__shoot" data-shoot>${ecIco('cam')}<span><b>${t('Prendre une photo')}</b><small>${t('Elle arrivera dans ta galerie, choisis-la ensuite ici.')}</small></span></button>
      <h2 class="ec-h2">${t('Ta galerie')}</h2>
      <div class="ec-grid" id="ec-grid">${loading()}</div></div>`, { dark: true });
  $('[data-shoot]', main).onclick = () => openApp('camera');
  const photos = await ecGallery();
  if (tok !== EC.tok) return;
  const grid = $('#ec-grid');
  if (!photos.length) { grid.innerHTML = `<p class="ec-muted">${t('Aucune photo : prends-en une avec l\'appareil photo.')}</p>`; return; }
  grid.innerHTML = photos.slice(0, 60).map((p, i) => `<button class="ec-grid__i" data-i="${i}"><img src="${esc(p.url)}" alt="" loading="lazy"></button>`).join('');
  $$('.ec-grid__i', grid).forEach(b => b.onclick = () => ecEdit(photos[+b.dataset.i].url, params.to));
}
function ecEdit(url, preTo, keep) {
  EC.draft = keep || { url, caption: '', duration: EC.limits.durations.includes(5) ? 5 : EC.limits.durations[0], to: preTo ? [preTo] : [] };
  const d = EC.draft;
  const main = ecShell('edit', `<div class="ec-edit">
      <img class="ec-edit__img" src="${esc(url)}" alt="">
      <header class="ec-edit__top"><button class="ec-ib" data-x aria-label="${t('Annuler')}">${ecIco('close')}</button>
        <div class="ec-edit__tools"><button class="ec-tool" data-text aria-label="${t('Texte')}">${ecIco('text')}</button><button class="ec-tool" data-timer aria-label="${t('Minuteur')}">${ecIco('timer')}<b id="ec-dur"></b></button></div></header>
      <input class="ec-cap ec-cap--edit" id="ec-cap" maxlength="${EC.limits.caption}" placeholder="${t('Écris quelque chose…')}" autocomplete="off">
      <footer class="ec-edit__foot"><button class="btn ec-btn ec-sendto" data-to>${t('Envoyer à')}${ecIco('send')}</button></footer></div>`, { bare: true, full: true });
  const durLbl = () => { $('#ec-dur').textContent = d.duration ? d.duration + 's' : '∞'; };
  durLbl();
  const cap = $('#ec-cap');
  cap.value = d.caption; cap.classList.toggle('has', !!d.caption);
  cap.oninput = () => { d.caption = cap.value; cap.classList.toggle('has', !!cap.value); };
  $('[data-text]', main).onclick = () => cap.focus();
  $('[data-timer]', main).onclick = () => {
    const i = EC.limits.durations.indexOf(d.duration);
    d.duration = EC.limits.durations[(i + 1) % EC.limits.durations.length]; durLbl();
  };
  $('[data-x]', main).onclick = () => ecRender({ page: 'camera' });
  $('[data-to]', main).onclick = () => ecPickFriends();
}
async function ecPickFriends() {
  const d = EC.draft;
  const r = await ecApi('ecFriends');
  const friends = r.friends || [];
  const sel = new Set(d.to);
  const main = ecShell('send', `${ecTop(t('Envoyer à…'))}
    <div class="ec-pad"><div class="ec-search">${ecIco('search')}<input class="field" id="ec-fq" placeholder="${t('Rechercher')}" autocomplete="off"></div></div>
    <div id="ec-flist"></div>
    <div class="ec-sendbar" id="ec-sendbar"><span id="ec-sel"></span><button class="ec-sendbtn" data-send aria-label="${t('Envoyer')}">${ecIco('send')}</button></div>`, { noNav: true });
  $('[data-back]', main).onclick = (e) => { e.stopPropagation(); d.to = [...sel]; ecEdit(d.url, null, d); };
  const draw = () => {
    const q = $('#ec-fq').value.trim().toLowerCase();
    const list = friends.filter(f => !q || f.name.toLowerCase().includes(q) || f.u.includes(q));
    $('#ec-flist').innerHTML = list.length ? list.map(f => `<button class="ec-pick ${sel.has(f.u) ? 'on' : ''}" data-u="${esc(f.u)}">${ecAv(f, 40)}<span><b>${esc(f.name)}</b><small>@${esc(f.u)}</small></span>${ecStreak(f.streak)}<i class="ec-check">${ecIco('check')}</i></button>`).join('')
      : `<div class="ec-pad">${empty(t('Aucun ami'), t('Ajoute des amis pour leur envoyer des snaps.'))}</div>`;
    $$('.ec-pick').forEach(b => b.onclick = () => { if (sel.has(b.dataset.u)) sel.delete(b.dataset.u); else if (sel.size < EC.limits.recipients) sel.add(b.dataset.u); draw(); });
    const names = friends.filter(f => sel.has(f.u)).map(f => f.name);
    $('#ec-sel').textContent = names.length ? names.join(', ') : t('Choisis tes amis');
    $('#ec-sendbar').classList.toggle('on', sel.size > 0);
  };
  $('#ec-fq').oninput = draw;
  draw();
  $('[data-send]', main).onclick = async () => {
    if (!sel.size) return;
    const btn = $('[data-send]', main); btn.disabled = true;
    const s = await ecApi('ecSendSnap', { url: d.url, caption: d.caption, duration: d.duration, to: [...sel] });
    btn.disabled = false;
    if (!s.ok) { ecToast(ecErr(s)); return; }
    if (EC.acc) EC.acc.score = s.score;
    EC.draft = null;
    ecToast(t('Snap envoyé à {n} ami(s) · +{p} ElyScore', { n: s.sent, p: s.sent }));
    ecTab('chats');
  };
}

/* =========================================================
   CARTE : amis qui partagent leur position avec moi
   ========================================================= */
async function ecMapPage(params, tok) {
  const main = ecShell('map', `<div class="ec-mapwrap"><div class="ec-map" id="ec-map"></div>
      <header class="ec-maptop"><button class="ec-me" data-me>${ecAv(EC.acc, 38)}</button><h1>${t('Carte')}</h1><button class="ec-ib ec-ib--glass" data-share aria-label="${t('Partage de position')}">${ecIco('gear')}</button></header>
      <div class="ec-ghost" id="ec-ghost"></div>
      <div class="ec-mapcard" id="ec-card"></div></div>`, { full: true });
  $('[data-me]', main).onclick = () => ecTab('me');
  $('[data-share]', main).onclick = () => ecShareSheet(() => ecMapPage(params, EC.tok));
  let first = true, data = null;
  EC.map = elyMap($('#ec-map'), { meters: 1500, onMe: () => data?.me && EC.map.center(data.me.x, data.me.y, 1400), onTap: () => { $('#ec-card').classList.remove('on'); } });
  const ghost = () => {
    $('#ec-ghost').innerHTML = EC.share === 'off' ? `<button class="ec-ghost__b" data-ghost>${ecIco('ghost')}<span><b>${t('Mode fantôme')}</b><small>${t('Tes amis ne voient pas ta position. Appuie pour la partager.')}</small></span></button>` : '';
    $('[data-ghost]')?.addEventListener('click', () => ecShareSheet(() => ecMapPage(params, EC.tok)));
  };
  ghost();
  const load = async () => {
    const r = await ecApi('ecMap');
    if (tok !== EC.tok || !EC.map) return;
    if (!r.ok) return;
    data = r; EC.share = r.share || EC.share; ghost();
    const mk = (r.friends || []).map(f => ({ id: 'f:' + f.u, x: f.x, y: f.y, z: 2, cls: 'ec-pin',
      html: `${ecAv(f, 44, true)}<span class="ec-pin__n">${esc(f.name.split(' ')[0])}${f.live ? '' : `<em>${ecAgo(f.ts)}</em>`}</span>`, onClick: () => ecMapCard(f) }));
    if (r.me) mk.push({ id: 'me', x: r.me.x, y: r.me.y, z: 3, cls: 'ec-pin ec-pin--me', html: `${ecAv(EC.acc, 48, true)}<span class="ec-pin__n">${t('Moi')}</span>` });
    EC.map.setMarkers(mk);
    if (first) {
      first = false;
      if (r.me) EC.map.center(r.me.x, r.me.y, 1500, true);
      else if ((r.friends || []).length) EC.map.fit(r.friends);
      else EC.map.center(-300, -900, 4000, true);
    }
  };
  await load();
  EC.mapTimer = setInterval(load, Math.max(5, EC.limits.mapRefresh) * 1000);
}
async function ecMapCard(f) {
  const card = $('#ec-card');
  const [place] = await elyPlaces([f]);
  card.innerHTML = `<div class="ec-card__h">${ecAv(f, 50, true)}<span><b>${esc(f.name)}</b><small>${ecIco('pin')}${esc(placeText(place, true) || t('Position partagée'))}</small>
    <small>${f.live ? `<i class="ec-live"></i>${t('En ce moment')}` : t('Vu il y a {t}', { t: ecAgo(f.ts) })}</small></span>${ecStreak(f.streak)}</div>
    <div class="ec-card__b"><button class="btn ec-btn" data-chat>${ecIco('chat')}${t('Chat')}</button><button class="btn ec-btn2" data-snap>${ecIco('cam')}${t('Snap')}</button><button class="btn ec-btn2" data-route>${ecIco('route')}${t('Y aller')}</button></div>`;
  card.classList.add('on');
  $('[data-chat]', card).onclick = () => ecGo('chat', { u: f.u });
  $('[data-snap]', card).onclick = () => ecGo('camera', { to: f.u });
  $('[data-route]', card).onclick = async () => { if (!IS_BROWSER) await post('waypointTo', { x: f.x, y: f.y }); ecToast(t('Point GPS posé sur {n}.', { n: f.name })); };
  EC.map?.center(f.x, f.y);
}

// Partage de position : tous mes amis, certains amis, personne (mode fantôme)
async function ecShareSheet(after) {
  const r = await ecApi('ecFriends');
  const friends = r.friends || [];
  let mode = r.share || EC.share;
  const sel = new Set(r.shareWith || []);
  openSheet(t('Ma position'), `<div class="ec-share">
      ${[['off', 'ghost', 'Mode fantôme', 'Personne ne voit ta position'], ['all', 'friends', 'Tous mes amis', 'Tous tes amis te voient sur la carte'], ['some', 'check', 'Seulement…', 'Choisis les amis qui te voient']].map(([k, ic, l, d]) =>
        `<button class="ec-opt ${mode === k ? 'on' : ''}" data-m="${k}">${ecIco(ic)}<span><b>${t(l)}</b><small>${t(d)}</small></span><i class="ec-radio"></i></button>`).join('')}
      <div class="ec-share__list" id="ec-sl"></div>
      <button class="btn btn--block ec-btn" data-ok>${t('Enregistrer')}</button></div>`, (sh) => {
    const draw = () => {
      $$('.ec-opt', sh).forEach(b => b.classList.toggle('on', b.dataset.m === mode));
      const l = $('#ec-sl', sh);
      l.innerHTML = mode === 'some' ? (friends.length ? friends.map(f => `<button class="ec-pick ec-pick--sm ${sel.has(f.u) ? 'on' : ''}" data-u="${esc(f.u)}">${ecAv(f, 32)}<span><b>${esc(f.name)}</b></span><i class="ec-check">${ecIco('check')}</i></button>`).join('') : `<p class="ec-muted">${t('Aucun ami pour l\'instant.')}</p>`) : '';
      $$('.ec-pick', l).forEach(b => b.onclick = () => { sel.has(b.dataset.u) ? sel.delete(b.dataset.u) : sel.add(b.dataset.u); draw(); });
    };
    $$('.ec-opt', sh).forEach(b => b.onclick = () => { mode = b.dataset.m; draw(); });
    draw();
    $('[data-ok]', sh).onclick = async () => {
      const s = await ecApi('ecSetShare', { mode, list: [...sel] });
      if (!s.ok) { ecToast(ecErr(s)); return; }
      EC.share = s.share; closeSheet();
      ecToast(s.share === 'off' ? t('Mode fantôme activé.') : t('Position partagée.'));
      after?.();
    };
  });
}

/* =========================================================
   AMIS : recherche, demandes, liste
   ========================================================= */
async function ecFriendsPage(params, tok) {
  const main = ecShell('friends', `${ecTop(t('Amis'), '', '<span class="ec-top__sp"></span>')}
    <div class="ec-pad"><div class="ec-search">${ecIco('search')}<input class="field" id="ec-q" placeholder="${t('Rechercher un nom ou @utilisateur')}" autocomplete="off"></div></div>
    <div id="ec-res"></div><div id="ec-fr">${loading()}</div>`);
  const r = await ecApi('ecFriends');
  if (tok !== EC.tok) return;
  const draw = (r) => {
    const sec = (title, list, kind) => !list.length ? '' : `<h2 class="ec-h2">${title}<em>${list.length}</em></h2>${list.map(u => `<div class="ec-frow" data-u="${esc(u.u)}">${ecAv(u, 44)}
      <span class="ec-frow__t"><b>${esc(u.name)}</b><small>@${esc(u.u)}${kind === 'friend' ? ` · ${(u.score || 0).toLocaleString(locale())} ${t('pts')}` : ''}</small></span>
      ${kind === 'in' ? `<button class="ec-pill ec-pill--y" data-acc>${t('Accepter')}</button><button class="ec-ib ec-ib--sm" data-dec aria-label="${t('Refuser')}">${ecIco('close')}</button>`
        : kind === 'out' ? `<span class="ec-pill ec-pill--off">${t('Demandé')}</span>` : `${ecStreak(u.streak)}<button class="ec-ib ec-ib--sm" data-chat aria-label="${t('Discuter')}">${ecIco('chat')}</button>`}</div>`).join('')}`;
    $('#ec-fr').innerHTML = sec(t('Demandes reçues'), r.incoming || [], 'in') + sec(t('Mes amis'), r.friends || [], 'friend') + sec(t('Demandes envoyées'), r.outgoing || [], 'out')
      || `<div class="ec-pad">${empty(t('Pas encore d\'amis'), t('Cherche le nom d\'utilisateur de tes amis ci-dessus.'))}</div>`;
    $$('#ec-fr .ec-frow').forEach(row => {
      const u = row.dataset.u;
      const f = (r.friends || []).concat(r.incoming || [], r.outgoing || []).find(x => x.u === u);
      $('[data-acc]', row)?.addEventListener('click', async () => { const s = await ecApi('ecRespond', { u, accept: true }); if (s.ok) { ecToast(t('Vous êtes maintenant amis !')); refresh(); } });
      $('[data-dec]', row)?.addEventListener('click', async () => { const s = await ecApi('ecRespond', { u, accept: false }); if (s.ok) refresh(); });
      $('[data-chat]', row)?.addEventListener('click', (e) => { e.stopPropagation(); ecGo('chat', { u }); });
      if ((r.friends || []).some(x => x.u === u)) row.onclick = (e) => { if (!e.target.closest('button')) ecFriendSheet(f, refresh); };
    });
  };
  const refresh = async () => { const x = await ecApi('ecFriends'); draw(x); const i = await ecApi('ecInit'); if (i.badges) { EC.badges = i.badges; ecSyncBadge(); } };
  draw(r);
  let timer;
  $('#ec-q').oninput = () => {
    clearTimeout(timer);
    timer = setTimeout(async () => {
      const q = $('#ec-q').value.trim();
      const box = $('#ec-res');
      if (q.length < 2) { box.innerHTML = ''; return; }
      const s = await ecApi('ecSearch', { q });
      const users = s.users || [];
      box.innerHTML = users.length ? `<h2 class="ec-h2">${t('Résultats')}</h2>${users.map(u => `<div class="ec-frow" data-u="${esc(u.u)}">${ecAv(u, 44)}<span class="ec-frow__t"><b>${esc(u.name)}</b><small>@${esc(u.u)}</small></span>
        ${u.rel === 'friends' ? `<span class="ec-pill ec-pill--off">${t('Ami')}</span>` : u.rel === 'sent' ? `<span class="ec-pill ec-pill--off">${t('Demandé')}</span>` : `<button class="ec-pill ec-pill--y" data-add>${u.rel === 'received' ? t('Accepter') : `+ ${t('Ajouter')}`}</button>`}</div>`).join('')}`
        : `<p class="ec-muted ec-pad">${t('Personne trouvé.')}</p>`;
      $$('[data-add]', box).forEach(b => b.onclick = async () => {
        const u = b.closest('.ec-frow').dataset.u;
        const a = await ecApi('ecAddFriend', { u });
        if (!a.ok) { ecToast(ecErr(a)); return; }
        b.outerHTML = `<span class="ec-pill ec-pill--off">${a.rel === 'friends' ? t('Ami') : t('Demandé')}</span>`;
        refresh();
      });
    }, 250);
  };
}
function ecFriendSheet(f, after) {
  openSheet('', `<div class="ec-fsheet">${ecAv(f, 84, true)}<h2>${esc(f.name)}</h2><p class="ec-muted">@${esc(f.u)}</p>
    <div class="ec-stats"><div><b>${(f.score || 0).toLocaleString(locale())}</b><small>${t('ElyScore')}</small></div><div><b>${f.streak || 0}${ecIco('flame')}</b><small>${t('Flammes')}</small></div></div>
    <div class="ec-card__b"><button class="btn ec-btn" data-chat>${ecIco('chat')}${t('Chat')}</button><button class="btn ec-btn2" data-snap>${ecIco('cam')}${t('Snap')}</button></div>
    <button class="btn btn--ghost btn--block ec-danger" data-rm>${t('Retirer des amis')}</button></div>`, (sh) => {
    $('[data-chat]', sh).onclick = () => { closeSheet(true); ecGo('chat', { u: f.u }); };
    $('[data-snap]', sh).onclick = () => { closeSheet(true); ecGo('camera', { to: f.u }); };
    $('[data-rm]', sh).onclick = () => confirmSheet(t('Retirer {n} ?', { n: esc(f.name) }), t('Vous ne pourrez plus vous envoyer de snaps, et il ne verra plus ta position.'), t('Retirer'), async () => {
      const s = await ecApi('ecRemoveFriend', { u: f.u });
      if (s.ok) { ecToast(t('Ami retiré.')); if (after) after(); else ecTab('friends'); }
    });
  });
}

/* =========================================================
   PROFIL : ElyScore, couleur, photo, partage de position
   ========================================================= */
async function ecMe(params, tok) {
  const a = EC.acc;
  const r = await ecApi('ecFriends');
  if (tok !== EC.tok) return;
  const shareLbl = { off: 'Mode fantôme', all: 'Tous mes amis', some: 'Certains amis' }[EC.share] || 'Mode fantôme';
  const main = ecShell('me', `<div class="ec-profile">
      <div class="ec-profile__hero" style="--c:${esc(a.color)}">${ecAv(a, 104, true)}</div>
      <h1>${esc(a.name)}</h1><p class="ec-muted">@${esc(a.u)}</p>
      <div class="ec-score">${ecIco('star')}<b>${(a.score || 0).toLocaleString(locale())}</b><span>${t('ElyScore')}</span></div>
      <p class="ec-muted ec-small">${t('+1 par snap photo envoyé à un ami, +1 par snap reçu ouvert.')}</p>
      <div class="ec-list">
        <button class="ec-li" data-edit>${ecIco('edit')}<span>${t('Modifier mon profil')}</span></button>
        <button class="ec-li" data-share>${ecIco('pin')}<span>${t('Ma position')}<small>${t(shareLbl)}</small></span></button>
        <button class="ec-li" data-friends>${ecIco('friends')}<span>${t('Mes amis')}<small>${(r.friends || []).length}</small></span></button>
      </div></div>`);
  $('[data-edit]', main).onclick = () => ecEditProfile();
  $('[data-share]', main).onclick = () => ecShareSheet(() => ecRender({ page: 'me' }));
  $('[data-friends]', main).onclick = () => ecTab('friends');
}
async function ecEditProfile() {
  const a = EC.acc;
  let color = a.color, avatar = a.avatar || '';
  const photos = await ecGallery();
  openSheet(t('Mon profil'), `<div class="ec-form">
      <div class="ec-preview" id="ec-pv2"></div>
      <label class="ec-lbl">${t('Nom affiché')}</label><input class="field" id="ec-d2" maxlength="30" value="${esc(a.name)}">
      <label class="ec-lbl">${t('Ta couleur')}</label>
      <div class="ec-colors">${EC.colors.map(c => `<button class="ec-color ${c === color ? 'on' : ''}" data-c="${c}" style="--c:${c}"></button>`).join('')}</div>
      <label class="ec-lbl">${t('Photo (de ta galerie)')}</label>
      <div class="ec-avpick"><button class="ec-avpick__i ${!avatar ? 'on' : ''}" data-a=""><b>Aa</b></button>${photos.slice(0, 11).map(p => `<button class="ec-avpick__i ${avatar === p.url ? 'on' : ''}" data-a="${esc(p.url)}"><img src="${esc(p.url)}" alt=""></button>`).join('')}</div>
      <p class="error-text" id="ec-e2"></p>
      <button class="btn btn--block ec-btn" data-ok>${t('Enregistrer')}</button></div>`, (sh) => {
    const pv = () => { $('#ec-pv2', sh).innerHTML = ecAv({ name: $('#ec-d2', sh).value || a.name, color, avatar }, 76, true); };
    pv();
    $('#ec-d2', sh).oninput = pv;
    $$('.ec-color', sh).forEach(b => b.onclick = () => { color = b.dataset.c; $$('.ec-color', sh).forEach(x => x.classList.toggle('on', x === b)); pv(); });
    $$('.ec-avpick__i', sh).forEach(b => b.onclick = () => { avatar = b.dataset.a; $$('.ec-avpick__i', sh).forEach(x => x.classList.toggle('on', x === b)); pv(); });
    $('[data-ok]', sh).onclick = async () => {
      const s = await ecApi('ecUpdateProfile', { display: $('#ec-d2', sh).value, color, avatar });
      if (!s.ok) { $('#ec-e2', sh).textContent = ecErr(s); return; }
      EC.acc = s.account; closeSheet(); ecRender({ page: 'me' });
    };
  });
}

const EC_PAGES = { chats: ecChats, chat: ecChat, camera: ecCamera, map: ecMapPage, friends: ecFriendsPage, me: ecMe };

/* ---------- Événements en direct (serveur → téléphone) ---------- */
function ecPush(d) {
  if (d.badges) { EC.badges = d.badges; ecSyncBadge(); if (typeof renderHome === 'function' && !S.currentApp && S.open && !S.locked) renderHome(); }
  const cur = S.stack[S.stack.length - 1];
  const here = S.open && S.currentApp === 'elychat' && cur?.id === 'elychat' && !EC.viewer;
  if (!here) return;
  const page = cur.params?.page || 'chats';
  if (d.type === 'chat' && page === 'chat' && EC.chatWith === d.from && EC.chatItems) { EC.chatItems.push(d.item); EC.chatDraw?.(); ecApi('ecChat', { u: d.from }); return; }
  if (['snap', 'chat', 'opened', 'seen'].includes(d.type) && page === 'chats') ecRender({ page: 'chats' });
  if (d.type === 'friends' && page === 'friends') ecRender({ page: 'friends' });
}

/* ---------- Aperçu navigateur (hors FiveM) : données de démonstration en mémoire ---------- */
const ECMock = (() => {
  const now = () => Math.floor(Date.now() / 1000);
  const img = (h, txt = '') => 'data:image/svg+xml;utf8,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="600" height="900"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="hsl(${h},75%,62%)"/><stop offset="1" stop-color="hsl(${(h + 70) % 360},70%,28%)"/></linearGradient></defs><rect width="600" height="900" fill="url(#g)"/><circle cx="420" cy="230" r="90" fill="rgba(255,255,255,.35)"/><path d="M0 700 L140 560 L260 640 L400 480 L600 700 V900 H0Z" fill="rgba(0,0,0,.35)"/><text x="36" y="850" font-family="sans-serif" font-size="40" fill="#fff">${txt}</text></svg>`);
  const gallery = [img(200, 'Vinewood'), img(20, 'Del Perro'), img(320, 'Selfie'), img(120, 'Plage'), img(260, 'Nuit')].map((u, i) => ({ id: i + 1, url: u, type: 'photo' }));
  const users = {
    me: { u: 'lena.duval', name: 'Léna Duval', color: '#FFD60A', avatar: null, score: 1284 },
    malik: { u: 'malik', name: 'Malik Benali', color: '#FF5A5F', avatar: img(20, 'M'), score: 3410 },
    ines: { u: 'ines.k', name: 'Inès Karim', color: '#3DDC97', avatar: null, score: 812 },
    tom: { u: 'tom_ls', name: 'Tom Lefèvre', color: '#5B6CFF', avatar: null, score: 95 },
    sarah: { u: 'sarah', name: 'Sarah Moreau', color: '#FF6FB5', avatar: img(300, 'S'), score: 2045 },
    jules: { u: 'jules.v', name: 'Jules Vidal', color: '#2EC4F1', avatar: null, score: 44 },
  };
  const D = {
    acc: null, share: 'all', shareWith: [],
    friends: { malik: 12, ines: 3, tom: 0 }, incoming: ['sarah'], outgoing: [],
    snaps: [{ id: 1, from: 'malik', to: 'me', url: img(30, 'Snap de Malik'), caption: 'Coucher de soleil sur la jetée', duration: 5, opened: false, ts: now() - 300 },
      { id: 2, from: 'malik', to: 'me', url: img(90, 'Snap 2'), caption: '', duration: 3, opened: false, ts: now() - 200 },
      { id: 3, from: 'me', to: 'ines', url: gallery[0].url, caption: '', duration: 5, opened: true, ts: now() - 5400 }],
    msgs: [{ id: 1, from: 'ines', to: 'me', body: 'On se rejoint au Bean Machine ?', seen: false, saved: false, ts: now() - 900 },
      { id: 2, from: 'me', to: 'tom', body: 'Bien arrivé ?', seen: true, saved: false, ts: now() - 7200 }],
    pos: { me: { x: -620, y: -230 }, malik: { x: -560, y: -380, live: true }, ines: { x: -1220, y: -1480, live: false, ts: now() - 1800 } },
  };
  const pub = (k) => Object.assign({}, users[k], { streak: D.friends[k] || 0 });
  const key = (u) => Object.keys(users).find(k => users[k].u === u);
  const badges = () => ({ snaps: D.snaps.filter(s => s.to === 'me' && !s.opened).length, chats: D.msgs.filter(m => m.to === 'me' && !m.seen).length, requests: D.incoming.length });
  let id = 100;
  return {
    call(n, a = {}) {
      if (n === 'getGallery') return { ok: true, photos: gallery };
      if (n === 'ecInit') return { ok: true, account: D.acc, share: D.share, badges: badges(), limits: { message: 400, caption: 80, recipients: 15, durations: [3, 5, 10, 0], chatHours: 24, mapRefresh: 15 }, colors: ['#FFD60A', '#FF5A5F', '#FF8A3D', '#3DDC97', '#2EC4F1', '#5B6CFF', '#B15CFF', '#FF6FB5'] };
      if (n === 'ecCreateAccount') {
        if (!a.username || a.username.length < 3) return { ok: false, error: 'Nom d\'utilisateur : 3 à 20 caractères, lettres, chiffres, _ ou .' };
        users.me.u = a.username; users.me.name = a.display || 'Léna Duval'; users.me.color = a.color || '#FFD60A';
        D.acc = Object.assign({}, users.me); return { ok: true, account: D.acc };
      }
      if (n === 'ecUpdateProfile') { users.me.name = a.display || users.me.name; users.me.color = a.color; users.me.avatar = a.avatar || null; D.acc = Object.assign({}, users.me); return { ok: true, account: D.acc }; }
      if (n === 'ecFriends') return { ok: true, friends: Object.keys(D.friends).map(pub), incoming: D.incoming.map(pub), outgoing: D.outgoing.map(pub), share: D.share, shareWith: D.shareWith };
      if (n === 'ecSearch') {
        const q = (a.q || '').toLowerCase();
        return { ok: true, users: Object.keys(users).filter(k => k !== 'me' && (users[k].u.includes(q) || users[k].name.toLowerCase().includes(q))).map(k => Object.assign(pub(k), { rel: D.friends[k] !== undefined ? 'friends' : D.incoming.includes(k) ? 'received' : D.outgoing.includes(k) ? 'sent' : 'none' })) };
      }
      if (n === 'ecAddFriend') { const k = key(a.u); if (D.incoming.includes(k)) { D.incoming = D.incoming.filter(x => x !== k); D.friends[k] = 0; return { ok: true, rel: 'friends' }; } D.outgoing.push(k); return { ok: true, rel: 'sent' }; }
      if (n === 'ecRespond') { const k = key(a.u); D.incoming = D.incoming.filter(x => x !== k); if (a.accept) D.friends[k] = 0; return { ok: true }; }
      if (n === 'ecRemoveFriend') { delete D.friends[key(a.u)]; return { ok: true }; }
      if (n === 'ecChats') {
        const out = Object.keys(D.friends).map(k => {
          const s = D.snaps.filter(x => (x.from === k && x.to === 'me') || (x.from === 'me' && x.to === k)).pop();
          const m = D.msgs.filter(x => (x.from === k && x.to === 'me') || (x.from === 'me' && x.to === k)).pop();
          let st = null;
          if (s && (!m || s.ts >= m.ts)) st = s.from === 'me' ? { kind: 'snap', dir: 'out', state: s.opened ? 'opened' : 'delivered', ts: s.ts } : { kind: 'snap', dir: 'in', state: s.opened ? 'opened' : 'new', ts: s.ts };
          else if (m) st = m.from === 'me' ? { kind: 'chat', dir: 'out', state: m.seen ? 'opened' : 'delivered', ts: m.ts } : { kind: 'chat', dir: 'in', state: m.seen ? 'opened' : 'new', ts: m.ts };
          const ns = D.snaps.filter(x => x.from === k && x.to === 'me' && !x.opened).length;
          const nc = D.msgs.filter(x => x.from === k && x.to === 'me' && !x.seen).length;
          if (nc && !ns) st = { kind: 'chat', dir: 'in', state: 'new', ts: m.ts };
          if (ns) st = { kind: 'snap', dir: 'in', state: 'new', ts: s.ts };
          return Object.assign(pub(k), { status: st, newSnaps: ns, newChats: D.msgs.filter(x => x.from === k && x.to === 'me' && !x.seen).length });
        }).sort((x, y) => (y.status?.ts || 0) - (x.status?.ts || 0));
        return { ok: true, chats: out, badges: badges() };
      }
      if (n === 'ecOpenSnap') {
        const k = key(a.u); const s = D.snaps.find(x => x.from === k && x.to === 'me' && !x.opened);
        if (!s) return { ok: false, error: 'Aucun nouveau snap' };
        s.opened = true; users.me.score++; D.acc && (D.acc.score = users.me.score);
        return { ok: true, snap: { url: s.url, caption: s.caption, duration: s.duration, ts: s.ts }, left: D.snaps.filter(x => x.from === k && x.to === 'me' && !x.opened).length };
      }
      if (n === 'ecChat') {
        const k = key(a.u);
        D.msgs.forEach(m => { if (m.from === k && m.to === 'me') m.seen = true; });
        const items = D.msgs.filter(m => (m.from === k && m.to === 'me') || (m.from === 'me' && m.to === k)).map(m => ({ id: m.id, kind: 'chat', mine: m.from === 'me', body: m.body, seen: m.seen, saved: m.saved, ts: m.ts }))
          .concat(D.snaps.filter(s => (s.from === k && s.to === 'me') || (s.from === 'me' && s.to === k)).map(s => ({ id: s.id, kind: 'snap', mine: s.from === 'me', opened: s.opened, ts: s.ts }))).sort((x, y) => x.ts - y.ts);
        return { ok: true, user: pub(k), items: items.slice() };
      }
      if (n === 'ecSend') { const m = { id: ++id, from: 'me', to: key(a.u), body: a.body, seen: false, saved: false, ts: now() }; D.msgs.push(m); return { ok: true, item: { id: m.id, kind: 'chat', mine: true, body: m.body, seen: false, saved: false, ts: m.ts } }; }
      if (n === 'ecSave') { const m = D.msgs.find(x => x.id === a.id); m.saved = !m.saved; return { ok: true, saved: m.saved }; }
      if (n === 'ecSendSnap') {
        const to = (a.to || []).map(key).filter(k => D.friends[k] !== undefined);
        if (!to.length) return { ok: false, error: 'Choisis au moins un ami' };
        to.forEach(k => D.snaps.push({ id: ++id, from: 'me', to: k, url: a.url, caption: a.caption, duration: a.duration, opened: false, ts: now() }));
        users.me.score += to.length; return { ok: true, sent: to.length, score: users.me.score };
      }
      if (n === 'ecMap') {
        const fr = Object.keys(D.friends).filter(k => D.pos[k]).map(k => Object.assign(pub(k), { x: D.pos[k].x, y: D.pos[k].y, live: D.pos[k].live, ts: D.pos[k].ts || now() }));
        return { ok: true, friends: fr, me: D.pos.me, share: D.share, now: now() };
      }
      if (n === 'ecSetShare') { D.share = a.mode; D.shareWith = a.list || []; return { ok: true, share: a.mode }; }
      return { ok: true };
    },
  };
})();
