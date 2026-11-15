/* =====================================================================
   ELYZEA LETTRES · INTERFACE
   Rédaction : trois vrais champs de saisie (invisibles) reçoivent le clavier — flèches, retour
   arrière, sélection, copier-coller fonctionnent comme partout — et le texte est dessiné en direct
   sur la feuille, avec le curseur à l'encre. Un clic sur la feuille place le curseur.
   Lecture : la même mise en page (layout.js), sans curseur.
   ===================================================================== */
(() => {
  const L = LetterLayout;
  const $ = (s) => document.querySelector(s);
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'elyzea_lettres';
  const post = (name, data = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
  const cps = (s) => [...(s || '')].length;   // longueur en caractères (un emoji = 1)

  const app = $('#app'), sheet = $('#sheet'), wrap = $('#sheet-wrap');
  const inputs = { recipient: $('#in-recipient'), body: $('#in-body'), signature: $('#in-signature') };
  const ORDER = ['recipient', 'body', 'signature'];
  const PH = { recipient: 'Destinataire…', body: 'Commencez votre lettre ici…', signature: 'Votre signature' };

  const S = {
    mode: null,             // 'write' | 'preview' | 'read' | 'envelope'
    letter: { recipient: '', body: '', signature: '', font: 'elegante', paper: 'creme' },
    date: '', limits: {}, fonts: [], papers: [], consume: 'letter',
    pages: [{ a: 0, b: 0, next: 0, head: true, sign: true }], page: 0,
    field: 'body', sel: null, layoutKey: '', dirty: false, saving: false, follow: true,
    readOpts: {}, busy: false,
  };

  // ---------- Mise à l'échelle ----------
  function fit() {
    const barH = ($('#bar').offsetHeight || 110) + 40;
    const availH = window.innerHeight - barH - 24;
    const availW = window.innerWidth - 150;
    const sc = Math.max(.35, Math.min(availH / L.H, availW / L.W, 1.6));
    sheet.style.transform = `scale(${sc})`;
    wrap.style.width = `${L.W * sc}px`;
    wrap.style.height = `${L.H * sc}px`;
    const env = $('#envelope');
    if (env) env.style.transform = `scale(${Math.max(.5, Math.min((window.innerWidth - 80) / 640, (window.innerHeight - barH) / 420, 1.5))})`;
  }
  window.addEventListener('resize', () => { fit(); render(); });

  // ---------- Rendu ----------
  function relayout() {
    const key = [S.letter.body, S.letter.font, S.letter.paper, S.letter.recipient, S.letter.signature, S.date].join('\u0001');
    if (key === S.layoutKey) return false;
    S.layoutKey = key;
    S.pages = L.paginate(S.letter, S.date);
    return true;
  }

  function currentSel() {
    if (S.mode !== 'write') return null;
    const el = inputs[S.field];
    if (!el || document.activeElement !== el) return { field: S.field, start: el ? el.value.length : 0, end: el ? el.value.length : 0, idle: true };
    return { field: S.field, start: el.selectionStart, end: el.selectionEnd };
  }

  function render() {
    if (!S.mode || S.mode === 'envelope') return;
    relayout();
    const n = S.pages.length;
    const sel = currentSel();
    if (S.mode === 'write' && S.follow && sel) S.page = L.pageOf(S.pages, sel.field, sel.field === 'body' ? sel.start : 0);
    S.page = Math.max(0, Math.min(S.page, n - 1));
    const p = S.pages[S.page];
    const caretPage = sel ? L.pageOf(S.pages, sel.field, sel.field === 'body' ? sel.start : 0) === S.page : false;
    sheet.className = L.pageClass(S.letter);
    sheet.innerHTML = L.pageHTML(S.letter, p, {
      date: S.date, index: S.page, total: n,
      sel: sel && !sel.idle ? sel : null, caret: caretPage && sel && !sel.idle,
      ph: S.mode === 'write' ? PH : {},
    });
    if (S.mode === 'write') sheet.querySelectorAll('[data-field]').forEach((f) => f.classList.toggle('active', f.dataset.field === S.field));
    $('#prev').disabled = S.page <= 0;
    $('#next').disabled = S.page >= n - 1;
    $('#prev').classList.toggle('hidden', n <= 1);
    $('#next').classList.toggle('hidden', n <= 1);
    if (S.mode === 'write' || S.mode === 'preview') {
      const c = cps(S.letter.body), max = S.limits.maxChars || 0;
      const over = n > (S.limits.maxPages || 99);
      $('#count').innerHTML = `${c.toLocaleString('fr-FR')} / ${max.toLocaleString('fr-FR')} caractères`;
      $('#pageinfo').innerHTML = over ? `<span class="over">${n} pages : ${S.limits.maxPages} au maximum</span>` : `Page ${S.page + 1} / ${n}`;
      $('#btn-finish').disabled = over || S.busy || !S.letter.body.trim();
    } else {
      $('#read-info').textContent = n > 1 ? `Page ${S.page + 1} / ${n}` : '';
    }
  }

  // Le curseur bouge (flèches, clic, sélection) : on redessine seulement si quelque chose a changé
  let lastSelKey = '';
  function tick() {
    if (S.mode === 'write') {
      const s = currentSel();
      const k = s ? `${s.field}:${s.start}:${s.end}:${s.idle ? 1 : 0}` : '';
      if (k !== lastSelKey) { lastSelKey = k; S.follow = true; render(); }
    }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);

  function focusField(field, pos) {
    S.field = field;
    const el = inputs[field];
    el.focus({ preventScroll: true });
    if (pos !== undefined) { const p = Math.max(0, Math.min(pos, el.value.length)); el.setSelectionRange(p, p); }
    S.follow = true;
    render();
  }

  // ---------- Saisie ----------
  ORDER.forEach((f) => {
    const el = inputs[f];
    el.addEventListener('focus', () => { S.field = f; });
    el.addEventListener('input', () => {
      S.letter[f] = el.value.replace(/\r/g, '');
      S.dirty = true; S.follow = true;
      render();
    });
    el.addEventListener('keydown', (e) => {
      if (S.mode !== 'write') return;
      if (e.key === 'Tab') { e.preventDefault(); const i = ORDER.indexOf(f); focusField(ORDER[(i + (e.shiftKey ? 2 : 1)) % 3]); return; }
      if (e.key === 'Enter' && f !== 'body') { e.preventDefault(); focusField(f === 'recipient' ? 'body' : 'body', f === 'recipient' ? 0 : undefined); return; }
      if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); askCancel(); }
    });
  });
  // garder le clavier dans un champ tant que la feuille est ouverte en écriture
  document.addEventListener('mousedown', (e) => {
    if (S.mode !== 'write' || e.target.closest('#modal')) return;
    // boutons (flèches, barre d'outils) : le clic marche, mais le clavier reste dans la lettre
    if (e.target.closest('#bar, .nav')) { if (e.target.closest('button')) e.preventDefault(); return; }
    const fieldEl = e.target.closest('[data-field]');
    if (!fieldEl || !sheet.contains(fieldEl)) {
      e.preventDefault();
      // clic sur la feuille hors des zones : le stylo va à la fin du texte de cette page
      if (sheet.contains(e.target)) { const p = S.pages[S.page]; return focusField('body', p ? p.b : S.letter.body.length); }
      inputs[S.field].focus({ preventScroll: true });
      return;
    }
    e.preventDefault();
    const field = fieldEl.dataset.field;
    const hit = L.posFromPoint(e.clientX, e.clientY);
    if (hit && hit.field === field) return focusField(field, hit.pos);
    if (field === 'body') {
      // clic dans le vide : fin de la ligne visée, ou fin du texte de la page
      const para = e.target.closest('.para');
      const body = sheet.querySelector('.p-body');
      const pos = para ? Number(para.dataset.le ?? S.letter.body.length) : Number(body && body.dataset.b);
      return focusField('body', Number.isFinite(pos) ? pos : S.letter.body.length);
    }
    focusField(field, inputs[field].value.length);
  });

  $('#prev').addEventListener('click', () => { S.follow = false; S.page--; render(); });
  $('#next').addEventListener('click', () => { S.follow = false; S.page++; render(); });

  // Brouillon : sauvegarde automatique côté serveur
  setInterval(() => {
    if ((S.mode === 'write' || S.mode === 'preview') && S.dirty) { S.dirty = false; post('draft', draft()); }
  }, 4000);
  const draft = () => ({ ...S.letter });
  const hasText = () => !!(S.letter.body.trim() || S.letter.recipient.trim() || S.letter.signature.trim());

  // ---------- Barre d'outils ----------
  function buildChoices() {
    $('#fonts').innerHTML = S.fonts.length > 1 ? S.fonts.map((f) => `<button class="chip ${f.id === S.letter.font ? 'on' : ''}" data-font="${f.id}" title="Écriture ${L.esc(f.label)}">
      <span class="aa font-${f.id}">Aa</span><small>${L.esc(f.label)}</small></button>`).join('') : '';
    $('#papers').innerHTML = S.papers.length > 1 ? S.papers.map((p) => `<button class="chip swatch ${p.id === S.letter.paper ? 'on' : ''}" data-paper="${p.id}" title="Papier ${L.esc(p.label)}"><i class="sw-${p.id}"></i></button>`).join('') : '';
  }
  $('#bar').addEventListener('mousedown', (e) => { if (!e.target.closest('button')) e.preventDefault(); });
  $('#fonts').addEventListener('click', (e) => {
    const b = e.target.closest('[data-font]'); if (!b) return;
    S.letter.font = b.dataset.font; S.dirty = true; buildChoices(); refocus();
  });
  $('#papers').addEventListener('click', (e) => {
    const b = e.target.closest('[data-paper]'); if (!b) return;
    S.letter.paper = b.dataset.paper; S.dirty = true; buildChoices(); refocus();
  });
  const refocus = () => { if (S.mode === 'write') focusField(S.field); else render(); };

  function setMode(m) {
    S.mode = m;
    app.className = `mode-${m}`;
    $('#bar-write').classList.toggle('hidden', !(m === 'write' || m === 'preview'));
    $('#bar-read').classList.toggle('hidden', m !== 'read');
    $('#bar-envelope').classList.toggle('hidden', m !== 'envelope');
    $('#stage').classList.toggle('hidden', m === 'envelope');
    $('#envelope-stage').classList.toggle('hidden', m !== 'envelope');
    $('#btn-preview').textContent = m === 'preview' ? 'Continuer d\'écrire' : 'Aperçu';
    const hints = {
      write: '<b>Clavier</b> : écrire · <b>Entrée</b> : nouvelle ligne · <b>Tab</b> : destinataire / lettre / signature · <b>Clic sur la feuille</b> : placer le stylo · <b>Échap</b> : quitter',
      preview: 'Aperçu de la lettre telle qu\'elle sera lue. Rien n\'est encore définitif.',
      read: '<b>← →</b> : changer de page · <b>Échap</b> : fermer',
      envelope: '<b>Échap</b> : fermer',
    };
    $('#hint').innerHTML = hints[m] || '';
    if (m !== 'write') ORDER.forEach((f) => inputs[f].blur());
    requestAnimationFrame(fit);
  }

  $('#btn-preview').addEventListener('click', () => {
    if (S.mode === 'preview') { setMode('write'); focusField(S.field); }
    else { setMode('preview'); S.follow = false; render(); }
  });
  $('#btn-cancel').addEventListener('click', () => askCancel());
  $('#btn-finish').addEventListener('click', () => askFinish());

  // ---------- Fenêtres ----------
  let modalCb = null;
  function modal(title, text, buttons) {
    $('#modal-title').textContent = title;
    $('#modal-text').innerHTML = text;
    $('#modal-btns').innerHTML = buttons.map((b, i) => `<button class="btn ${b.cls || ''}" data-mb="${i}">${L.esc(b.label)}</button>`).join('');
    modalCb = (i) => { $('#modal').classList.add('hidden'); modalCb = null; buttons[i] && buttons[i].fn && buttons[i].fn(); };
    $('#modal').classList.remove('hidden');
    ORDER.forEach((f) => inputs[f].blur());
    setTimeout(() => { const last = $('#modal-btns').lastElementChild; if (last) last.focus(); }, 30);
  }
  $('#modal').addEventListener('click', (e) => { const b = e.target.closest('[data-mb]'); if (b && modalCb) modalCb(Number(b.dataset.mb)); });
  const modalOpen = () => !$('#modal').classList.contains('hidden');
  const back = () => { if (S.mode === 'write') focusField(S.field); else render(); };

  function askCancel() {
    if (S.busy) return;
    if (!hasText()) { post('cancel', { keep: false }); return hideUi(); }
    modal('Quitter la lettre ?', 'Votre lettre n\'est pas terminée. La feuille ne sera <b>pas</b> utilisée.<br>Vous pouvez garder le brouillon pour le reprendre plus tard, en reprenant une feuille.', [
      { label: 'Jeter le brouillon', cls: 'danger', fn: () => modal('Jeter ce brouillon ?', 'Le texte écrit sera définitivement perdu.', [
        { label: 'Non, revenir', fn: back },
        { label: 'Oui, tout jeter', cls: 'danger', fn: () => { post('cancel', { keep: false }); hideUi(); } },
      ]) },
      { label: 'Continuer d\'écrire', fn: back },
      { label: 'Garder le brouillon', cls: 'primary', fn: () => { post('cancel', { keep: true, draft: draft() }); hideUi(); } },
    ]);
  }

  function askFinish() {
    if (S.busy || !S.letter.body.trim()) return;
    const n = S.pages.length;
    const sheets = S.consume === 'none' ? 0 : (S.consume === 'page' ? n : 1);
    const to = S.letter.recipient.trim();
    const warn = [];
    if (!to) warn.push('pas de destinataire');
    if (!S.letter.signature.trim()) warn.push('pas de signature (lettre anonyme)');
    modal('Terminer la lettre ?', `${to ? `Lettre pour <b>${L.esc(to)}</b>` : 'Lettre'} · ${n} page${n > 1 ? 's' : ''}${sheets ? ` · ${sheets} feuille${sheets > 1 ? 's' : ''} utilisée${sheets > 1 ? 's' : ''}` : ''}.<br>
      ${warn.length ? `<i>Attention : ${warn.join(', ')}.</i><br>` : ''}Une fois terminée, la lettre <b>ne pourra plus être modifiée</b>.`, [
      { label: 'Revenir', fn: back },
      { label: 'Terminer la lettre', cls: 'primary', fn: () => {
        S.busy = true; render();
        post('finish', { recipient: S.letter.recipient, body: S.letter.body, signature: S.letter.signature, font: S.letter.font, paper: S.letter.paper, pages: n });
      } },
    ]);
  }

  let toastT = null;
  function toast(text, ok) {
    const t = $('#toast');
    t.textContent = text; t.className = ok ? 'ok' : '';
    clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), 4200);
  }

  // ---------- Lecture / enveloppe ----------
  $('#btn-close').addEventListener('click', () => closeUi());
  $('#btn-close-env').addEventListener('click', () => closeUi());
  $('#btn-open-env').addEventListener('click', () => { $('#envelope').classList.add('open'); setTimeout(() => post('openEnvelope'), 550); });
  $('#btn-envelope').addEventListener('click', () => post('putInEnvelope'));
  $('#btn-takeout').addEventListener('click', () => post('takeOut'));

  function closeUi() { post('close'); hideUi(); }
  function hideUi() {
    S.mode = null;
    app.classList.add('hidden');
    $('#modal').classList.add('hidden');
    wrap.classList.remove('folding');
    $('#toast').classList.add('hidden');
    ORDER.forEach((f) => inputs[f].blur());
  }

  document.addEventListener('keydown', (e) => {
    if (!S.mode) return;
    if (modalOpen()) { if (e.key === 'Escape') { e.preventDefault(); back(); $('#modal').classList.add('hidden'); } return; }
    if (S.mode === 'write') return;     // géré par les champs
    if (e.key === 'Escape' || e.key === 'Backspace') {
      e.preventDefault();
      if (S.mode === 'preview') { setMode('write'); focusField(S.field); } else closeUi();
    } else if (e.key === 'ArrowLeft' && S.page > 0) { S.page--; render(); }
    else if (e.key === 'ArrowRight' && S.page < S.pages.length - 1) { S.page++; render(); }
  });

  async function fontsReady(font) {
    const fam = { elegante: 'LettreElegante', naturelle: 'LettreNaturelle', arrondie: 'LettreArrondie' }[font] || 'LettreElegante';
    try { await Promise.all([document.fonts.load(`25px ${fam}`, 'Éé àç'), document.fonts.load(`600 25px ${fam}`, 'Aa')]); } catch (e) { /* police manquante : police de secours */ }
  }

  function showLetter(letter, opts) {
    S.letter = { recipient: letter.recipient || '', body: letter.body || '', signature: letter.signature || '', font: letter.font, paper: letter.paper };
    S.date = letter.date || ''; S.readOpts = opts || {}; S.page = 0; S.layoutKey = '';
    $('#btn-envelope').classList.toggle('hidden', !S.readOpts.canEnvelope);
    $('#btn-takeout').classList.toggle('hidden', !S.readOpts.fromEnvelope);
    app.classList.remove('hidden');
    setMode('read');
    fontsReady(letter.font).then(() => { S.layoutKey = ''; render(); });
    render();
  }

  // ---------- Messages du jeu ----------
  window.addEventListener('message', async (ev) => {
    const m = ev.data || {};
    if (m.action === 'write') {
      const d = m.data || {};
      S.limits = d.limits || {}; S.fonts = d.fonts || []; S.papers = d.papers || []; S.consume = d.consume || 'letter';
      S.date = d.date || '';
      const dr = d.draft || {};
      S.letter = {
        recipient: dr.recipient || '', body: dr.body || '', signature: dr.signature || '',
        font: (S.fonts.find((f) => f.id === dr.font) || S.fonts.find((f) => f.id === d.defaultFont) || S.fonts[0] || { id: 'elegante' }).id,
        paper: (S.papers.find((p) => p.id === dr.paper) || S.papers[0] || { id: 'creme' }).id,
      };
      inputs.recipient.maxLength = S.limits.recipient || 60;
      inputs.signature.maxLength = S.limits.signature || 60;
      inputs.body.maxLength = S.limits.maxChars || 3000;
      ORDER.forEach((f) => { inputs[f].value = S.letter[f]; });
      S.busy = false; S.dirty = false; S.layoutKey = ''; S.page = 0;
      wrap.classList.remove('folding');
      app.classList.remove('hidden');
      buildChoices();
      setMode('write');
      await Promise.all(S.fonts.map((f) => fontsReady(f.id)));
      S.layoutKey = '';
      focusField(S.letter.recipient ? 'body' : 'recipient', S.letter.recipient ? S.letter.body.length : 0);
      if (dr.body || dr.recipient) toast('Brouillon retrouvé : vous reprenez votre lettre là où vous l\'aviez laissée.', true);
    } else if (m.action === 'finished') {
      S.busy = false;
      if (m.ok) { setMode('preview'); render(); wrap.classList.add('folding'); }
      else { toast(m.message || 'Impossible de terminer la lettre.'); setMode('write'); focusField(S.field); }
    } else if (m.action === 'read') {
      showLetter(m.letter || {}, m.opts);
    } else if (m.action === 'envelope') {
      const e = m.envelope || {};
      app.classList.remove('hidden');
      $('#env-name').textContent = e.recipient || '';
      $('#env-name').className = `font-${e.font || 'elegante'}`;
      $('#envelope').classList.toggle('open', false);
      $('#env-seal').classList.toggle('hidden', e.opened === true);
      $('#btn-open-env').textContent = e.opened ? 'Lire la lettre' : 'Ouvrir l\'enveloppe';
      setMode('envelope');
    } else if (m.action === 'hide') {
      hideUi();
    }
  });

  // Aperçu hors jeu (ouvrir index.html dans un navigateur) : ?demo
  if (!window.invokeNative && /[?&]demo/.test(location.search)) {
    window.postMessage({ action: 'write', data: { limits: { maxChars: 3000, maxPages: 4, recipient: 60, signature: 60 },
      fonts: [{ id: 'elegante', label: 'Élégante' }, { id: 'naturelle', label: 'Naturelle' }, { id: 'arrondie', label: 'Arrondie' }],
      papers: [{ id: 'creme', label: 'Crème' }, { id: 'ligne', label: 'Blanc ligné' }, { id: 'ancien', label: 'Vieilli' }],
      date: 'Los Santos, le 15 novembre 2026', defaultFont: 'elegante', consume: 'letter' } }, '*');
  }
})();
