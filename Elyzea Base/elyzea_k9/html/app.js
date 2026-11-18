'use strict';
/* =====================================================================
   ELYZEA K9 — interface (menu du chien, création, dressage, ordres,
   historique ; affichages du mode ciblage et des exercices)
   Toutes les actions passent par le serveur (aucune décision ici).
   ===================================================================== */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_k9';
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
async function post(name, data = {}) {
  if (window.__k9mock) return window.__k9mock(name, data);
  try { const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }); return await r.json(); }
  catch (e) { return {}; }
}

const ICON = { follow: '🐕', stay: '✋', sit: '🪑', lie: '🛏️', come: '📣', search: '🔎', defend: '🛡️', sniffp: '👃', sniffv: '🚗', bark: '🗣️', intim: '😠', attack: '⚡', takedown: '🤼', track: '🧭' };
const ORDER_HINT = { none: 'Immédiat', player: 'Choisir une personne', vehicle: 'Choisir un véhicule' };
const SKILL_ICON = { sniff: '👃', obey: '🎯', attack: '⚡', track: '🧭', defense: '🛡️', intim: '😠' };
const S = { data: null, side: null, tab: 'dog', draft: null };

const sideData = () => S.data && S.data.sides.find(x => x.side === S.side);
const dog = () => sideData() && sideData().dog;
const fmtMin = (s) => s >= 60 ? `${Math.ceil(s / 60)} min` : `${s} s`;

function confirmBox(title, text, yes) {
  $('#mTitle').textContent = title; $('#mText').textContent = text;
  $('#modal').classList.remove('hidden');
  $('#mYes').onclick = () => { $('#modal').classList.add('hidden'); yes(); };
  $('#mNo').onclick = () => $('#modal').classList.add('hidden');
}

/* ---------- En-tête ---------- */
function renderHead() {
  const sd = sideData();
  const gang = S.side === 'gang';
  document.body.classList.toggle('gang', gang);
  $('#logo').textContent = gang ? '🐺' : '🚓';
  $('#title').textContent = gang ? 'Chiens du groupe' : 'Unité cynophile';
  $('#sub').textContent = gang ? (sd.info.groupLabel || 'Groupe') : (sd.duty ? 'En service' : (sd.dutyError || 'Hors service'));
  $('#sides').innerHTML = S.data.sides.length > 1 ? S.data.sides.map(x => `<button data-side="${x.side}" class="${x.side === S.side ? 'on' : ''}">${x.side === 'police' ? 'Police' : 'Groupe'}</button>`).join('') : '';
  $$('#sides [data-side]').forEach(b => b.onclick = () => { S.side = b.dataset.side; S.tab = 'dog'; S.draft = null; post('previewStop'); render(); });
}

function render() {
  renderHead();
  const d = dog();
  const menu = $('#menu');
  if (!d) {
    menu.classList.remove('center'); menu.classList.add('side');
    $('#tabs').innerHTML = '';
    return renderCreate();
  }
  menu.classList.add('center'); menu.classList.remove('side');
  const tabs = [['dog', 'Mon chien'], ['train', 'Dressage', d.points > 0 ? d.points : 0], ['orders', 'Ordres'], ['history', 'Historique']];
  $('#tabs').innerHTML = tabs.map(([k, l, n]) => `<button data-tab="${k}" class="${S.tab === k ? 'on' : ''}">${l}${n ? `<span class="pill">${n}</span>` : ''}</button>`).join('');
  $$('#tabs [data-tab]').forEach(b => b.onclick = () => { S.tab = b.dataset.tab; render(); });
  ({ dog: renderDog, train: renderTrain, orders: renderOrders, history: renderHistory })[S.tab]();
}

/* ---------- Création : race (aperçu réel), spécialité, nom ---------- */
function renderCreate() {
  const sd = sideData();
  const police = S.side === 'police';
  const breeds = S.data.breeds.filter(b => b.sides[S.side]);
  S.draft = S.draft || { step: 1, breed: (breeds.find(b => b.available) || {}).id, specialty: null, name: '' };
  const D = S.draft;
  const steps = police ? 3 : 2;
  const bar = `<div class="steps">${Array.from({ length: steps }, (_, i) => `<i class="${i < D.step ? 'on' : ''}"></i>`).join('')}</div>`;
  let html = bar, foot = '';
  if (D.step === 1) {
    html += `<p class="hint">Choisis la race de ton chien. Chaque race est un modèle différent, avec ses points forts réels. L'aperçu s'affiche devant toi.</p>
      <div class="breeds">${breeds.map(b => `<button class="breed ${D.breed === b.id ? 'on' : ''} ${b.available ? '' : 'na'}" data-breed="${b.id}" ${b.available ? '' : 'disabled'}>
        <b>${esc(b.label)}</b><span class="tag ${b.addon ? '' : 'acc'}">${b.available ? (b.addon ? 'Addon' : 'GTA V') : 'Modèle non installé'}</span>
        <p>${esc(b.desc)}</p>
        <div class="traits">${Object.entries(b.traits).map(([k, v]) => `<span>${k[0].toUpperCase() + k.slice(1)}<div class="dots">${[1, 2, 3, 4, 5].map(i => `<i class="${i <= v ? 'on' : ''}"></i>`).join('')}</div></span>`).join('')}</div></button>`).join('')}</div>
      <div class="rotate"><button class="btn" data-rot="-35">⟲ Tourner</button><button class="btn" data-rot="35">Tourner ⟳</button></div>`;
    foot = `<button class="btn primary" id="next" ${D.breed ? '' : 'disabled'}>Continuer</button>`;
  } else if (D.step === 2 && police) {
    html += `<p class="hint">Sa spécialité principale : elle fixe les compétences qu'il pourra porter au plus haut.</p>
      <div class="specs">${S.data.specialties.map(s => `<button class="spec ${D.specialty === s.id ? 'on' : ''}" data-spec="${s.id}"><span class="ic">${s.icon}</span><div><b>${esc(s.label)}</b><small>${esc(s.desc)}</small>
        <small>Plafonds : ${Object.entries(s.caps).map(([k, v]) => `${skillLabel(k)} ${v}`).join(' · ')}</small></div></button>`).join('')}</div>`;
    foot = `<button class="btn" id="prev">Retour</button><button class="btn primary" id="next" ${D.specialty ? '' : 'disabled'}>Continuer</button>`;
  } else {
    const b = S.data.breeds.find(x => x.id === D.breed);
    const s = police ? S.data.specialties.find(x => x.id === D.specialty) : null;
    html += `<p class="hint">Dernière étape : son nom.</p><input type="text" id="dname" maxlength="18" placeholder="Nom du chien (ex. Rex)" value="${esc(D.name)}">
      <div class="card"><h3>Récapitulatif</h3><div class="tags"><span class="tag acc">${esc(b ? b.label : '')}</span>${s ? `<span class="tag">${s.icon} ${esc(s.label)}</span>` : `<span class="tag">${esc(sd.info.groupLabel || 'Groupe')}</span>`}</div>
      <p class="hint">${police ? 'Ton chien commence avec sa spécialité au niveau 2. Entraîne-le et réalise des interventions pour le faire progresser.' : 'Attaque, défense et intimidation commencent au niveau 1 : entraîne ton chien pour le rendre redoutable.'}</p></div>
      <p class="err small" id="cerr"></p>`;
    foot = `<button class="btn" id="prev">Retour</button><button class="btn primary" id="create">Adopter</button>`;
  }
  $('#body').innerHTML = html + `<div class="foot" style="margin:0 -16px -16px">${foot}</div>`;
  $$('[data-breed]').forEach(b => b.onclick = () => { D.breed = b.dataset.breed; const br = S.data.breeds.find(x => x.id === D.breed); post('preview', { model: br.model }); renderCreate(); });
  $$('[data-rot]').forEach(b => b.onclick = () => post('previewRotate', { deg: +b.dataset.rot }));
  $$('[data-spec]').forEach(b => b.onclick = () => { D.specialty = b.dataset.spec; renderCreate(); });
  const next = $('#next'); if (next) next.onclick = () => { D.step = police ? D.step + 1 : 3; renderCreate(); };
  const prev = $('#prev'); if (prev) prev.onclick = () => { D.step = police ? D.step - 1 : 1; renderCreate(); };
  const nm = $('#dname'); if (nm) { nm.oninput = () => { D.name = nm.value; }; nm.focus(); }
  const cr = $('#create'); if (cr) cr.onclick = async () => {
    cr.disabled = true;
    const r = await post('create', { side: S.side, breed: D.breed, specialty: D.specialty, name: D.name });
    cr.disabled = false;
    if (!r.ok) { $('#cerr').textContent = r.error || 'Création impossible.'; return; }
    sideData().dog = r.dog; S.draft = null; S.tab = 'dog'; render();
  };
  if (D.step === 1 && D.breed) { const br = S.data.breeds.find(x => x.id === D.breed); if (br) post('preview', { model: br.model }); }
}
function skillLabel(id) {
  for (const side of Object.values(S.data.skills)) for (const s of side) if (s.id === id) return s.label;
  return id;
}

/* ---------- Fiche du chien ---------- */
function renderDog() {
  const d = dog(), sd = sideData();
  const breed = S.data.breeds.find(b => b.id === d.breed);
  const spec = S.data.specialties.find(s => s.id === d.specialty);
  const pct = d.xpNext > 0 ? Math.min(100, Math.round(d.xp / d.xpNext * 100)) : 100;
  const out = S.data.active && S.data.active.side === S.side;
  const state = d.injured > 0 ? `<div class="state hurt"><i></i>Blessé : au chenil encore ${fmtMin(d.injured)}</div>`
    : out ? `<div class="state out"><i></i>Sorti avec toi · santé ${d.health} %</div>` : `<div class="state"><i></i>Au chenil · santé ${d.health} %</div>`;
  const m = d.missions || {};
  $('#body').innerHTML = `<div class="grid2">
    <div class="card">
      <div class="dogname"><span class="av">${S.side === 'gang' ? '🐺' : '🐕'}</span><div class="sp"><h2>${esc(d.name)}<button class="edit" id="rename" title="Renommer">✎</button></h2>
        <div class="tags"><span class="tag acc">${esc(breed ? breed.label : d.breed)}</span>${spec ? `<span class="tag">${spec.icon} ${esc(spec.label)}</span>` : ''}</div></div>
        <span class="lvl" style="--p:${pct}"><span>${d.level}</span></span></div>
      <div class="meter"><span>Expérience</span><span>${d.level >= d.maxLevel ? 'Niveau maximal' : `${d.xp} / ${d.xpNext} XP`}</span><div class="xpbar"><i style="width:${pct}%"></i></div></div>
      ${state}
      <div class="row">
        ${out ? `<button class="btn" id="reward">❤️ Récompenser</button><button class="btn danger" id="store">Renvoyer au chenil</button>`
              : `<button class="btn primary" id="spawn" ${(!sd.duty || d.injured > 0) ? 'disabled' : ''}>Faire sortir ${esc(d.name)}</button>`}
      </div>
      ${!sd.duty && S.side === 'police' ? `<p class="hint warn">${esc(sd.dutyError || 'Prends ton service pour sortir ton chien.')}</p>` : ''}
    </div>
    <div class="card">
      <h3>Interventions</h3>
      <div class="stats"><div><b>${(m.sniff || 0)}</b><small>Détections</small></div><div><b>${(m.takedown || 0)}</b><small>Mises au sol</small></div><div><b>${(m.found || 0)}</b><small>Retrouvés</small></div></div>
      <h3>Aujourd'hui</h3>
      <div class="meter"><span>Entraînement</span><span>${d.trainXp} / ${d.trainCap} XP</span><div class="xpbar"><i style="width:${Math.min(100, d.trainXp / d.trainCap * 100)}%"></i></div></div>
      <div class="meter"><span>Interventions</span><span>${d.missionXp} / ${d.missionCap} XP</span><div class="xpbar"><i style="width:${Math.min(100, d.missionXp / d.missionCap * 100)}%"></i></div></div>
      <p class="hint">Points de compétence : <b>${d.points}</b>${d.points ? ' — onglet Dressage pour les dépenser.' : ''}</p>
    </div></div>`;
  const sp = $('#spawn'); if (sp) sp.onclick = () => post('spawn', { side: S.side });
  const st = $('#store'); if (st) st.onclick = () => post('store', {});
  const rw = $('#reward'); if (rw) rw.onclick = () => post('reward', {});
  $('#rename').onclick = () => {
    const box = $('#modal .box');
    $('#mTitle').textContent = 'Renommer';
    $('#mText').innerHTML = `<input type="text" id="newname" maxlength="18" value="${esc(d.name)}">`;
    $('#modal').classList.remove('hidden');
    $('#newname').focus();
    $('#mYes').onclick = async () => {
      const r = await post('rename', { side: S.side, name: $('#newname').value });
      if (!r.ok) { $('#mText').insertAdjacentHTML('beforeend', `<p class="err small">${esc(r.error || 'Nom invalide.')}</p>`); return; }
      $('#modal').classList.add('hidden'); sideData().dog = r.dog; render();
    };
    $('#mNo').onclick = () => $('#modal').classList.add('hidden');
    return box;
  };
}

/* ---------- Dressage : compétences + exercices ---------- */
function renderTrain(flash) {
  const d = dog();
  const out = S.data.active && S.data.active.side === S.side;
  const spec = S.data.specialties.find(s => s.id === d.specialty);
  const skills = d.skills.map(s => {
    const isMain = spec && spec.main === s.id;
    const next = s.level < s.cap ? s.levels[s.level] : null;
    return `<div class="skill ${flash === s.id ? 'flash' : ''}" data-skill="${s.id}">
      <div><b>${SKILL_ICON[s.id] || ''} ${esc(s.label)}</b>${isMain ? '<span class="main">Spécialité</span>' : ''}</div>
      <div class="dots">${[1, 2, 3, 4, 5].map(i => `<i class="${i <= s.level ? 'on' : (i > s.cap ? 'lock' : '')}"></i>`).join('')}</div>
      ${s.cost ? `<button class="btn ${d.points >= s.cost ? 'primary' : ''}" data-up="${s.id}" ${d.points >= s.cost ? '' : 'disabled'}>Améliorer · ${s.cost} pt${s.cost > 1 ? 's' : ''}</button>`
               : `<span class="tag">${s.level >= 5 ? 'Maximum' : 'Plafond'}</span>`}
      <p><b>Niveau ${s.level} :</b> ${esc(s.levels[s.level - 1])}${next ? `<br><b>Niveau ${s.level + 1} :</b> ${esc(next)}` : ''}${s.trained ? ` · ${s.trained} séance(s)` : ''}</p></div>`;
  }).join('');
  const exs = d.exercises.map(e => `<div class="ex"><div class="row"><b>${SKILL_ICON[e.skill] || '🎓'} ${esc(e.label)}</b><span class="sp"></span><span class="tag acc">+${e.xp} XP</span></div>
      <p>${esc(e.desc)}</p><div class="row"><small>⏱ ${Math.round(e.seconds / 60 * 10) / 10} min max</small><span class="sp"></span>
      <button class="btn" data-ex="${e.id}" ${(!out || e.wait > 0) ? 'disabled' : ''}>${e.wait > 0 ? `Repos ${fmtMin(e.wait)}` : 'Commencer'}</button></div></div>`).join('');
  $('#body').innerHTML = `<div class="points"><span>Points de compétence</span><span class="sp"></span><b>${d.points}</b></div>
    <div class="card"><h3>Compétences</h3>${skills}</div>
    <div class="card"><h3>Exercices<span class="small muted">${out ? 'Ton chien est prêt.' : 'Sors ton chien pour l\'entraîner.'}</span></h3><div class="exs">${exs}</div>
    <p class="hint">Chaque exercice se fait en jeu. Le même exercice refait dans l'heure rapporte moins (et demande un temps de repos). Limite d'entraînement : ${d.trainCap} XP par jour.</p></div>`;
  $$('[data-up]').forEach(b => b.onclick = async () => {
    b.disabled = true;
    const r = await post('upgrade', { side: S.side, skill: b.dataset.up });
    if (!r.ok) { b.disabled = false; b.textContent = r.error || 'Impossible'; return; }
    sideData().dog = r.dog; renderTrain(b.dataset.up);
    setTimeout(() => { const el = $(`.skill[data-skill="${b.dataset.up}"]`); if (el) el.classList.remove('flash'); }, 1400);
  });
  $$('[data-ex]').forEach(b => b.onclick = () => post('exercise', { id: b.dataset.ex }));
}

/* ---------- Ordres ---------- */
function renderOrders() {
  const out = S.data.active && S.data.active.side === S.side;
  const list = S.data.orders.filter(o => S.side === 'police' || !o.police);
  $('#body').innerHTML = `<p class="hint">${out ? `Clique sur un ordre. Les ordres avec cible ouvrent le <b>mode ciblage</b> : <kbd>Molette</kbd> pour choisir la personne, <kbd>E</kbd> pour confirmer, <kbd>Échap</kbd> pour annuler. Raccourci direct : <kbd>${esc(S.data.keys.target)}</kbd>.` : 'Sors ton chien pour lui donner des ordres.'}</p>
    <div class="orders">${list.map(o => `<button class="order" data-order="${o.id}" ${out ? '' : 'disabled'}><span class="ic">${ICON[o.id] || '•'}</span><span>${esc(o.label)}<small>${ORDER_HINT[o.target]}</small></span></button>`).join('')}</div>
    <p class="hint">La réussite dépend du dressage : un chien peu obéissant hésite ou refuse, un chien expérimenté exécute plus vite. Tu peux aussi faire <kbd>ALT</kbd> sur ton chien pour les ordres rapides.</p>`;
  $$('[data-order]').forEach(b => b.onclick = () => post('order', { order: b.dataset.order }));
}

/* ---------- Historique ---------- */
function renderHistory() {
  const d = dog();
  const ic = { train: '🎓', mission: '🚨', level: '⭐', skill: '📈', info: '🐾' };
  $('#body').innerHTML = d.history.length ? `<div class="hist">${d.history.map(h => `<div><span>${ic[h.kind] || '•'}</span><span>${esc(h.label)}</span>
      ${h.xp ? `<span class="xp">+${h.xp} XP</span>` : '<span></span>'}<small>${new Date(h.ts * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}</small></div>`).join('')}</div>`
    : '<div class="empty">Aucun entraînement ni intervention pour le moment.</div>';
}

/* ---------- Affichages de jeu ---------- */
function target(d) {
  const el = $('#target');
  if (!d.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  $('#tgOrder').textContent = d.order;
  $('#tgName').textContent = d.name || (d.kind === 'vehicle' ? 'Aucun véhicule à portée' : 'Personne à portée');
  $('#tgInfo').textContent = d.name ? `${d.dist} m · ${d.index} / ${d.count}${d.dog ? ` · ${d.dog}` : ''}` : 'Approche-toi de la cible';
  const w = $('#tgWarn'); w.textContent = d.warn || ''; w.classList.toggle('hidden', !d.warn);
}
function hud(d) {
  const el = $('#hud');
  if (!d.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  $('#hudTitle').textContent = d.title || '';
  $('#hudText').textContent = d.text || '';
  $('#hudBarWrap').classList.toggle('hidden', d.progress === undefined || d.progress === null);
  $('#hudBar').style.width = `${Math.max(0, Math.min(1, d.progress || 0)) * 100}%`;
  $('#hudExtra').textContent = d.extra || '';
  $('#hudAbort').textContent = d.abort || '';
}

window.addEventListener('message', (e) => {
  const { action, data } = e.data || {};
  if (action === 'open') {
    S.data = data; S.draft = null; S.tab = 'dog';
    S.side = (data.active && data.sides.some(x => x.side === data.active.side)) ? data.active.side : data.sides[0].side;
    $('#menu').classList.remove('hidden'); render();
  } else if (action === 'close') {
    $('#menu').classList.add('hidden'); $('#modal').classList.add('hidden');
  } else if (action === 'dog' && S.data && data) {
    const sd = S.data.sides.find(x => x.side === data.side); if (sd) { sd.dog = data; if (!$('#menu').classList.contains('hidden') && S.side === data.side) render(); }
  } else if (action === 'target') target(data || {});
  else if (action === 'hud') hud(data || {});
  else if (action === 'previewMissing') {
    const b = S.data && S.data.breeds.find(x => x.model === data.model); if (b) { b.available = false; if (S.draft) S.draft.breed = null; render(); }
  }
});
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape' || $('#menu').classList.contains('hidden')) return;
  if (!$('#modal').classList.contains('hidden')) { $('#modal').classList.add('hidden'); return; }
  post('close');
});
$('[data-close]').onclick = () => post('close');
