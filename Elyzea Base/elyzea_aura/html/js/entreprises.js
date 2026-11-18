'use strict';
/* =========================================================
   ENTREPRISES — entreprises créées par les joueurs (elyzea_entreprises)
   · « Entreprise » : toutes les entreprises (logo, spécialité, description) ;
     Appeler → sonne sur le téléphone de service de tous les employés en service,
     le premier qui décroche prend l'appel ; Message → leur appli « Entreprise ».
   · « Lancer mon Business » : nom, spécialité, logo, description, paiement →
     l'entreprise est créée et le joueur en devient le patron.
     Membre d'une entreprise : sa vitrine (logo, spécialité, description, couleur).
   · Logo : galerie du téléphone, lien d'image, ou depuis l'ordinateur (page web + code).
   Tout est revérifié par le serveur (paiement, droits, textes, liens).
   ========================================================= */
const Ent = { tab: 'list', list: null, specs: [], q: '', spec: '', mine: null, draft: null, poll: null };
const entApi = (n, a) => (IS_BROWSER ? EntMock.call(n, a) : api(n, a));
const entInit = (n) => (String(n || '').split(/\s+/).filter(Boolean).map(p => p[0]).join('').slice(0, 2) || '?').toUpperCase();
// lien d'image sûr dans un style CSS (guillemets, parenthèses et espaces encodés)
const entCssUrl = (u) => String(u || '').replace(/['"()\\\s]/g, (ch) => '%' + ch.charCodeAt(0).toString(16).padStart(2, '0'));
const entLogo = (c, cls = '') => c && c.logo
  ? `<span class="ent-logo ${cls}" style="background-image:url('${esc(entCssUrl(c.logo))}')"></span>`
  : `<span class="ent-logo ent-logo--none ${cls}" style="--ec:${esc((c && c.color) || '#7C6CFF')}">${esc(entInit(c && c.name))}</span>`;
const entMoney = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
function entToast(text, title) { notify({ app: 'entreprises', title: title || t('Entreprises'), text }); }

Views.entreprises = async (params = {}) => {
  if (params.tab) Ent.tab = params.tab;
  const action = `<button class="icon-btn" data-ent-maj aria-label="${t('Actualiser')}">${icon('reset')}</button>`;
  frame({ title: t('Entreprises'), action,
    tabs: tabsHtml([['list', t('Entreprise')], ['launch', t('Lancer mon Business')]], Ent.tab, 'data-ent-tab'), body: loading() });
  appView.querySelector('.app').classList.add('ent');
  $('[data-ent-maj]', appView).onclick = () => { Ent.list = null; Ent.mine = null; Views.entreprises(); };
  $$('[data-ent-tab]', appView).forEach(b => b.onclick = () => { Ent.tab = b.dataset.entTab; Views.entreprises(); });
  if (Ent.tab === 'launch') return entLaunch();
  return entList();
};

/* ---------------------------------------------------------
   Onglet « Entreprise » : annuaire
   --------------------------------------------------------- */
async function entList() {
  const r = await entApi('entList');
  if (S.currentApp !== 'entreprises' || Ent.tab !== 'list') return;
  const body = $('.app__body', appView);
  if (!r || !r.ok) { body.innerHTML = empty(t('Entreprises indisponibles'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  Ent.list = r.list || []; Ent.specs = r.specialties || [];
  // nom de l'entreprise à la place de son numéro (Messages, Téléphone)
  S.bizNames = S.bizNames || {};
  Ent.list.forEach(c => { if (c.number) S.bizNames[c.number] = c.name; });
  const used = Ent.specs.filter(s => Ent.list.some(c => c.specialty === s.id));
  body.innerHTML = `<input class="field ent-search" id="ent-q" placeholder="${t('Rechercher une entreprise…')}" value="${esc(Ent.q)}">
    ${used.length ? `<div class="ent-chips"><button class="ent-chip ${Ent.spec ? '' : 'on'}" data-ent-spec="">${t('Toutes')}</button>${used.map(s => `<button class="ent-chip ${Ent.spec === s.id ? 'on' : ''}" data-ent-spec="${esc(s.id)}">${esc(s.icon)} ${esc(t(s.label))}</button>`).join('')}</div>` : ''}
    <div id="ent-list"></div>`;
  $('#ent-q').oninput = (e) => { Ent.q = e.target.value; entDraw(); };
  $$('[data-ent-spec]', body).forEach(b => b.onclick = () => { Ent.spec = b.dataset.entSpec; $$('[data-ent-spec]', body).forEach(x => x.classList.toggle('on', x === b)); entDraw(); });
  entDraw();
}

function entDraw() {
  const box = $('#ent-list', appView); if (!box) return;
  const q = Ent.q.trim().toLowerCase();
  const list = Ent.list.filter(c => (!Ent.spec || c.specialty === Ent.spec)
    && (!q || `${c.name} ${c.specialtyLabel} ${c.description} ${c.number || ''}`.toLowerCase().includes(q)));
  if (!list.length) {
    box.innerHTML = empty(Ent.list.length ? t('Aucun résultat') : t('Aucune entreprise pour l\'instant'),
      Ent.list.length ? t('Essayez un autre mot.') : t('Soyez le premier : onglet « Lancer mon Business ».'));
    return;
  }
  box.innerHTML = `<div class="ent-cards">${list.map(c => `<div class="ent-card ${c.onDuty > 0 && c.open ? 'is-on' : ''}" style="--ec:${esc(c.color)}" data-ent-open="${c.id}">
      <div class="ent-card__top">${entLogo(c)}
        <div class="ent-card__main"><div class="ent-card__name">${esc(c.name)}</div>
          <div class="ent-card__sub">${esc(c.specialtyIcon || '')} ${esc(t(c.specialtyLabel || ''))}</div></div>
        <span class="ent-state">${c.onDuty > 0 && c.open ? t('{n} en service', { n: c.onDuty }) : c.open ? t('Personne en service') : t('Fermée')}</span></div>
      <p class="ent-card__desc">${esc(c.description || '')}</p>
      <div class="ent-card__actions">
        <button class="btn btn--sm ${c.onDuty > 0 && c.open ? '' : 'btn--ghost'}" data-ent-call="${esc(c.number || '')}" ${c.number ? '' : 'disabled'}>${icon('phone')}${t('Appeler')}</button>
        <button class="btn btn--sm btn--ghost" data-ent-msg="${esc(c.number || '')}" ${c.number ? '' : 'disabled'}>${icon('messages')}${t('Message')}</button>
      </div></div>`).join('')}</div>`;
  $$('[data-ent-call]', box).forEach(b => b.onclick = (e) => { e.stopPropagation(); if (b.dataset.entCall) startCall(b.dataset.entCall); });
  $$('[data-ent-msg]', box).forEach(b => b.onclick = (e) => { e.stopPropagation(); if (b.dataset.entMsg) openApp('messages', { number: b.dataset.entMsg }); });
  $$('[data-ent-open]', box).forEach(el => el.onclick = () => entDetail(Ent.list.find(c => String(c.id) === el.dataset.entOpen)));
}

function entDetail(c) {
  if (!c) return;
  const on = c.onDuty > 0 && c.open;
  openSheet('', `<div class="ent-detail" style="--ec:${esc(c.color)}">
      ${entLogo(c, 'ent-logo--xl')}
      <h2 class="ent-detail__name">${esc(c.name)}</h2>
      <p class="ent-detail__spec">${esc(c.specialtyIcon || '')} ${esc(t(c.specialtyLabel || ''))}</p>
      <p class="ent-detail__desc">${esc(c.description || '')}</p>
      <div class="ent-detail__meta">
        <span><b>${esc(c.number || '—')}</b>${t('Numéro')}</span>
        <span><b>${c.employees}</b>${t('Employé(s)')}</span>
        <span><b class="${on ? 'ok' : ''}">${on ? c.onDuty : 0}</b>${t('En service')}</span>
      </div>
      <p class="ent-detail__note">${on ? t('Un appel sonne chez tous les employés en service : le premier qui décroche vous répond.')
        : t('Personne n\'est en service : laissez un message, il arrivera sur le téléphone de l\'entreprise.')}</p>
      <p class="ent-detail__by">${t('Fondée par {n}', { n: esc(c.owner || '—') })}${c.created ? ` · ${esc(c.created)}` : ''}</p>
      <div class="form"><button class="btn btn--block" data-d-call ${c.number ? '' : 'disabled'}>${icon('phone')}${t('Appeler')}</button>
        <button class="btn btn--ghost btn--block" data-d-msg ${c.number ? '' : 'disabled'}>${icon('messages')}${t('Envoyer un message')}</button></div></div>`, (sh) => {
    $('[data-d-call]', sh).onclick = () => { closeSheet(true); startCall(c.number); };
    $('[data-d-msg]', sh).onclick = () => { closeSheet(true); openApp('messages', { number: c.number }); };
  });
}

/* ---------------------------------------------------------
   Onglet « Lancer mon Business » / « Mon business »
   --------------------------------------------------------- */
async function entLaunch() {
  const r = await entApi('entMine');
  if (S.currentApp !== 'entreprises' || Ent.tab !== 'launch') return;
  const body = $('.app__body', appView);
  if (!r || !r.ok) { body.innerHTML = empty(t('Entreprises indisponibles'), esc(t((r && r.error) || 'Réessayez dans un instant.'))); return; }
  Ent.mine = r;
  if (r.state === 'member') return entMember(body, r);
  if (r.state === 'away') return entAway(body, r);
  return entCreateForm(body, r);
}

function entFields(r, d, editName) {
  return `${editName ? `<label class="ent-label">${t('Nom de l\'entreprise')}</label>
      <input class="field" id="ent-name" maxlength="${r.nameMax || 40}" placeholder="${t('Ex : Vinewood Événements')}" value="${esc(d.name || '')}">` : ''}
    <label class="ent-label">${t('Logo')}</label>
    <div class="ent-logopick">${entLogo({ logo: d.logo, name: d.name || (r.company && r.company.name), color: d.color }, 'ent-logo--lg')}
      <div class="ent-logopick__btns"><button class="btn btn--sm" id="ent-logo-btn">${icon('image')}${d.logo ? t('Changer le logo') : t('Choisir un logo')}</button>
        <small>${t('Galerie, lien d\'image ou depuis votre ordinateur')}</small></div></div>
    <label class="ent-label">${t('Spécialité')}</label>
    <div class="ent-specs">${(r.specialties || []).map(s => `<button class="ent-spec ${d.specialty === s.id ? 'on' : ''}" data-spec="${esc(s.id)}"><span>${esc(s.icon)}</span>${esc(t(s.label))}</button>`).join('')}</div>
    <label class="ent-label">${t('Couleur')}</label>
    <div class="ent-colors">${(r.colors || []).map(c => `<button class="ent-color ${d.color === c ? 'on' : ''}" data-color="${esc(c)}" style="background:${esc(c)}" aria-label="${esc(c)}"></button>`).join('')}</div>
    <label class="ent-label">${t('Description')}</label>
    <textarea class="field" id="ent-desc" rows="5" maxlength="${r.descriptionMax || 600}" placeholder="${t('Ce que fait votre entreprise, vos horaires, vos tarifs…')}">${esc(d.description || '')}</textarea>
    <p class="ent-count" id="ent-count"></p>`;
}
function entBindFields(r, d, rerender) {
  const keep = () => {
    const n = $('#ent-name', appView); if (n) d.name = n.value;
    const de = $('#ent-desc', appView); if (de) d.description = de.value;
  };
  $('#ent-name', appView)?.addEventListener('input', keep);
  const de = $('#ent-desc', appView);
  const count = () => { const c = $('#ent-count', appView); if (c && de) c.textContent = `${de.value.length} / ${r.descriptionMax || 600}`; };
  de?.addEventListener('input', () => { keep(); count(); });
  count();
  $$('[data-spec]', appView).forEach(b => b.onclick = () => { keep(); d.specialty = b.dataset.spec; $$('[data-spec]', appView).forEach(x => x.classList.toggle('on', x === b)); });
  $$('[data-color]', appView).forEach(b => b.onclick = () => { keep(); d.color = b.dataset.color; rerender(); });
  $('#ent-logo-btn', appView).onclick = () => { keep(); entLogoSheet(d, rerender); };
  return keep;
}

function entCreateForm(body, r) {
  const d = Ent.draft = Ent.draft && !Ent.draft.forProfile ? Ent.draft : { name: '', specialty: '', logo: '', description: '', color: (r.colors || [])[0] || '#7C6CFF' };
  const blocked = !r.canCreate;
  body.innerHTML = `<div class="ent-hero"><div class="ent-hero__ico">${icon('briefcase')}</div>
      <div><h2>${t('Lancez votre entreprise')}</h2><p>${t('Vous en serez le patron, avec un téléphone et une tablette d\'entreprise (F6) pour recruter, gérer les grades, les salaires et répondre aux clients.')}</p></div></div>
    <div class="ent-price"><span>${t('Coût de création')}</span><b>${entMoney(r.price)}</b><small>${t('Payé depuis votre compte en banque')}${r.bank != null ? ` · ${t('solde')} ${entMoney(r.bank)}` : ''}</small></div>
    ${blocked ? `<div class="ent-warn">${esc(t(r.reason || 'Création impossible pour le moment.'))}</div>` : ''}
    ${!blocked && r.current ? `<div class="ent-warn ent-warn--soft">${t('Vous quitterez votre métier actuel ({j}) en devenant patron.', { j: esc(r.current) })}</div>` : ''}
    <div class="ent-form ${blocked ? 'is-off' : ''}">${entFields(r, d, true)}
      <p class="ent-hint">${t('Pas de point ni de logo sur la carte : les clients vous trouvent ici, dans l\'onglet « Entreprise ».')}</p>
      <button class="btn btn--block" id="ent-create" ${blocked ? 'disabled' : ''}>${t('Créer mon entreprise · {p}', { p: entMoney(r.price) })}</button>
      <p class="ent-err" id="ent-err"></p></div>`;
  const keep = entBindFields(r, d, () => entCreateForm(body, r));
  $('#ent-create', appView).onclick = () => {
    keep();
    const err = (m) => { $('#ent-err', appView).textContent = m; };
    if ((d.name || '').trim().length < 3) return err(t('Donnez un nom à votre entreprise.'));
    if (!d.specialty) return err(t('Choisissez une spécialité.'));
    if (!d.logo) return err(t('Choisissez un logo.'));
    if ((d.description || '').trim().length < 10) return err(t('Décrivez votre entreprise (10 caractères au moins).'));
    err('');
    confirmSheet(t('Créer « {n} » ?', { n: esc(d.name.trim()) }),
      `${t('{p} seront retirés de votre compte en banque.', { p: entMoney(r.price) })}${r.current ? `<br>${t('Vous quitterez votre métier actuel ({j}).', { j: esc(r.current) })}` : ''}`,
      t('Payer et créer'), async () => {
        const res = await entApi('entCreate', { name: d.name, specialty: d.specialty, logo: d.logo, description: d.description, color: d.color, leaveJob: !!r.current });
        if (!res || !res.ok) return err(t((res && res.error) || 'Création impossible.'));
        Ent.draft = null; Ent.list = null;
        entToast(t(res.message || 'Entreprise créée.'), t('Félicitations !'));
        Views.entreprises({ tab: 'launch' });
      });
  };
}

function entMember(body, r) {
  const c = r.company;
  const d = Ent.draft = Ent.draft && Ent.draft.forProfile === c.id ? Ent.draft
    : { forProfile: c.id, name: c.name, logo: c.logo, specialty: c.specialty, description: c.description, color: c.color };
  body.innerHTML = `<div class="ent-mine" style="--ec:${esc(c.color)}">${entLogo(c, 'ent-logo--lg')}
      <div><h2>${esc(c.name)}</h2><p>${esc(c.specialtyIcon || '')} ${esc(t(c.specialtyLabel || ''))} · ${esc(r.grade)}</p>
        <p class="ent-mine__num">${c.number ? `${t('Numéro public')} : <b>${esc(c.number)}</b>` : ''}${c.onDuty ? ` · ${t('{n} en service', { n: c.onDuty })}` : ''}</p></div></div>
    ${r.suspended ? `<div class="ent-warn">${t('Entreprise suspendue par le staff.')}</div>` : ''}
    <div class="ent-tip">${icon('phone')}<span>${t('Téléphone et tablette d\'entreprise : touche F6 (prendre son service, répondre aux clients, recruter, payer les salaires).')}</span></div>
    ${r.canProfile ? `<p class="section-label">${t('Ma vitrine')}</p><div class="ent-form">${entFields(r, d, false)}
        <button class="btn btn--block" id="ent-save">${t('Enregistrer la vitrine')}</button><p class="ent-err" id="ent-err"></p></div>`
      : `<p class="ent-hint">${t('Votre grade ne permet pas de modifier la vitrine.')}</p>`}`;
  if (!r.canProfile) return;
  const keep = entBindFields(r, d, () => entMember(body, r));
  $('#ent-save', appView).onclick = async () => {
    keep();
    const res = await entApi('entProfile', { logo: d.logo, specialty: d.specialty, description: d.description, color: d.color });
    if (!res || !res.ok) { $('#ent-err', appView).textContent = t((res && res.error) || 'Enregistrement impossible.'); return; }
    Ent.draft = null; Ent.list = null;
    entToast(t(res.message || 'Vitrine mise à jour.'));
    Views.entreprises({ tab: 'launch' });
  };
}

function entAway(body, r) {
  const c = r.company;
  body.innerHTML = `<div class="ent-mine" style="--ec:${esc(c.color)}">${entLogo(c, 'ent-logo--lg')}<div><h2>${esc(c.name)}</h2>
      <p>${t('Vous avez fondé cette entreprise mais vous avez pris un autre métier.')}</p></div></div>
    <button class="btn btn--block" id="ent-reclaim">${t('Reprendre ma place de patron')}</button><p class="ent-err" id="ent-err"></p>`;
  $('#ent-reclaim', appView).onclick = async () => {
    let res = await entApi('entReclaim', {});
    if (res && res.needLeave) {
      return confirmSheet(t('Quitter votre métier ?'), t('Vous quitterez votre métier actuel ({j}).', { j: esc(res.needLeave) }), t('Reprendre ma place'), async () => {
        res = await entApi('entReclaim', { leaveJob: true });
        if (!res || !res.ok) { $('#ent-err', appView).textContent = t((res && res.error) || 'Impossible.'); return; }
        entToast(t(res.message)); Views.entreprises({ tab: 'launch' });
      });
    }
    if (!res || !res.ok) { $('#ent-err', appView).textContent = t((res && res.error) || 'Impossible.'); return; }
    entToast(t(res.message)); Views.entreprises({ tab: 'launch' });
  };
}

/* ---------------------------------------------------------
   Choix du logo : galerie, lien, ordinateur
   --------------------------------------------------------- */
async function entLogoSheet(d, done) {
  const g = await entApi('getGallery');
  const photos = ((g && g.photos) || []).filter(p => (p.type || 'photo') === 'photo');
  const set = (url) => { d.logo = url; closeSheet(); done(); };
  openSheet(t('Logo de l\'entreprise'), `
    <button class="ent-pc" data-pc>${icon('upload')}<span><b>${t('Depuis mon ordinateur')}</b><small>${t('PNG, JPG… : une page s\'ouvre dans votre navigateur')}</small></span></button>
    <p class="section-label">${t('Galerie du téléphone')}</p>
    ${photos.length ? `<div class="picker">${photos.slice(0, 18).map(p => `<button data-pick="${esc(p.url)}" style="background-image:url('${esc(entCssUrl(p.url))}')"></button>`).join('')}</div>`
      : `<p class="sheet__text">${t('Votre galerie est vide.')}</p>`}
    <div class="form" style="margin-top:10px"><input class="field" id="ent-url" placeholder="${t('Ou collez le lien d\'une image (https://…)')}">
      <button class="btn btn--block" id="ent-url-go">${t('Utiliser ce lien')}</button><p class="ent-err" id="ent-url-err"></p></div>`, (sh) => {
    $$('[data-pick]', sh).forEach(b => b.onclick = () => set(b.dataset.pick));
    $('#ent-url-go', sh).onclick = () => {
      const u = $('#ent-url', sh).value.trim();
      if (!/^https:\/\/[^\s"'<>()]+$/.test(u)) { $('#ent-url-err', sh).textContent = t('Lien https d\'une image attendu.'); return; }
      set(u);
    };
    $('[data-pc]', sh).onclick = () => { closeSheet(true); entPcSheet(d, done); };
  });
}

function entOpenUrl(url) {
  if (typeof window.invokeNative === 'function') window.invokeNative('openUrl', url);
  else window.open(url, '_blank');
}
async function entPcSheet(d, done) {
  const r = await entApi('entLogoCode');
  if (!r || !r.ok) return entToast(t((r && r.error) || 'Import impossible.'));
  entOpenUrl(r.url);
  const end = Date.now() + r.minutes * 60000;
  const sh = openSheet(t('Depuis mon ordinateur'), `<div class="ent-pcsheet">
      <ol class="ent-steps">
        <li><b>1</b><span>${t('La page s\'ouvre dans le navigateur de votre ordinateur (Alt+Tab), code déjà rempli.')}
          <button class="btn btn--sm btn--ghost" data-reopen>${t('Rouvrir la page')}</button></span></li>
        <li><b>2</b><span>${t('Sinon, allez sur')} <code>${esc(r.url.replace(/\?.*$/, ''))}</code> ${t('et tapez ce code :')}</span></li>
      </ol>
      <div class="ent-code">${esc(r.code.slice(0, 3))}<i></i>${esc(r.code.slice(3))}</div>
      <p class="ent-small" id="ent-exp"></p>
      <ol class="ent-steps" start="3"><li><b>3</b><span>${t('Choisissez votre image ({m} Mo max) : elle arrive ici toute seule.', { m: r.maxMb })}</span></li></ol>
      <div class="ent-wait"><span class="ent-dots"><i></i><i></i><i></i></span>${t('En attente de votre image…')}</div></div>`, (s) => {
    $('[data-reopen]', s).onclick = () => entOpenUrl(r.url);
  });
  clearInterval(Ent.poll);
  Ent.poll = setInterval(async () => {
    if (!document.body.contains(sh)) { clearInterval(Ent.poll); return; }
    const left = Math.max(0, Math.round((end - Date.now()) / 1000));
    const ex = $('#ent-exp', sh);
    if (ex) ex.textContent = left > 0 ? t('Code valable encore {m} min {s} s', { m: Math.floor(left / 60), s: String(left % 60).padStart(2, '0') }) : t('Code expiré : rouvrez cette fenêtre.');
    if (left <= 0) { clearInterval(Ent.poll); return; }
    if (left % 2) return;   // une demande toutes les 2 secondes
    const p = await entApi('entLogoPending');
    if (p && p.ok && p.url) {
      clearInterval(Ent.poll);
      d.logo = p.url;
      closeSheet();
      entToast(t('Logo reçu depuis votre ordinateur.'));
      done();
    }
  }, 1000);
}

/* ---------------------------------------------------------
   Aperçu navigateur (sans le jeu)
   --------------------------------------------------------- */
const EntMock = (() => {
  const specs = [{ id: 'commerce', label: 'Commerce', icon: '🛍️' }, { id: 'evenementiel', label: 'Événementiel', icon: '🎉' }, { id: 'securite', label: 'Sécurité privée', icon: '🛡️' }, { id: 'autre', label: 'Autre', icon: '🏢' }];
  const colors = ['#7c6cff', '#3b82f6', '#10b981', '#f97316', '#ef4444', '#ec4899'];
  const img = (seed) => `data:image/svg+xml;utf8,${encodeURIComponent(`<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><rect width='64' height='64' rx='14' fill='${seed}'/><text x='32' y='42' font-size='28' text-anchor='middle' fill='white' font-family='Arial' font-weight='bold'>★</text></svg>`)}`;
  let list = [
    { id: 1, name: 'Vinewood Événements', specialty: 'evenementiel', specialtyLabel: 'Événementiel', specialtyIcon: '🎉', logo: img('#ec4899'), color: '#ec4899', description: 'Mariages, anniversaires, soirées privées : on organise tout, de la déco au DJ.\nDevis gratuit par message.', owner: 'Léa Moreau', created: '12/11/2026', employees: 4, number: '919-0001', open: true, onDuty: 2 },
    { id: 2, name: 'Blackwood Sécurité', specialty: 'securite', specialtyLabel: 'Sécurité privée', specialtyIcon: '🛡️', logo: '', color: '#3b82f6', description: 'Agents de sécurité pour vos événements et vos commerces, 24 h/24.', owner: 'Marcus Reed', created: '15/11/2026', employees: 7, number: '919-0002', open: true, onDuty: 0 },
  ];
  let mine = { ok: true, state: 'none', canCreate: true, current: 'Mécano', bank: 48200, price: 25000 };
  let pending = null;
  const H = {
    entList: () => ({ ok: true, list, specialties: specs }),
    entMine: () => Object.assign({ specialties: specs, colors, descriptionMax: 600, nameMax: 40, price: 25000 }, mine),
    entCreate: (a) => {
      if (list.some(c => c.name.toLowerCase() === String(a.name).trim().toLowerCase())) return { ok: false, error: 'Une entreprise porte déjà ce nom.' };
      const s = specs.find(x => x.id === a.specialty) || specs[3];
      const c = { id: list.length + 1, name: a.name.trim(), specialty: s.id, specialtyLabel: s.label, specialtyIcon: s.icon, logo: a.logo, color: a.color, description: a.description, owner: 'Moi', created: '18/11/2026', employees: 1, number: `919-000${list.length + 1}`, open: true, onDuty: 0 };
      list = list.concat([c]);
      mine = { ok: true, state: 'member', company: c, grade: 'Patron', canProfile: true, owner: true };
      return { ok: true, message: `« ${c.name} » est créée : vous en êtes le patron.` };
    },
    entProfile: (a) => { Object.assign(mine.company, a); return { ok: true, message: 'Vitrine mise à jour.' }; },
    entReclaim: () => ({ ok: true, message: 'ok' }),
    entLogoCode: () => { setTimeout(() => { pending = img('#10b981'); }, 2500); return { ok: true, code: 'K7P2QD', url: 'http://127.0.0.1:30120/elyzea_entreprises/logo?code=K7P2QD', minutes: 15, maxMb: 5 }; },
    entLogoPending: () => { const u = pending; pending = null; return { ok: true, url: u }; },
    getGallery: () => ({ ok: true, photos: [{ id: 1, url: img('#f97316') }, { id: 2, url: img('#7c6cff') }] }),
  };
  return { call: async (n, a) => (H[n] || (() => ({ ok: false, error: 'inconnu' })))(a || {}) };
})();
