/* =====================================================================
   ELYZEA ENTREPRISES - modération staff (/entreprises_admin)
   Suspendre / réactiver, retirer un logo ou une description, renommer, dissoudre.
   ===================================================================== */
(() => {
  const A = { open: false, list: [], q: '' };
  const box = () => $('#admin .modal');
  const initials = (n) => (String(n || '').split(/\s+/).map((p) => p[0] || '').join('').slice(0, 2) || '?').toUpperCase();
  function draw() {
    const q = A.q.trim().toLowerCase();
    const list = A.list.filter((c) => !q || `${c.name} ${c.owner} ${c.specialtyLabel} ${c.id}`.toLowerCase().includes(q));
    box().innerHTML = `<div class="modal-head"><div><div class="eyebrow">Staff</div><h2>Entreprises des joueurs <span class="faint" style="font-size:.85rem">${A.list.length}</span></h2></div>
        <button class="icon-btn" data-ad="close" aria-label="Fermer">✕</button></div>
      <div class="toolbar"><input class="input grow" id="adQ" placeholder="Rechercher : nom, fondateur, spécialité, numéro" value="${esc(A.q)}"></div>
      <div class="admin-list">${list.map((c) => `<div class="card adm-row ${c.enabled ? '' : 'off'}">
          <div class="vitrine">${c.logo ? `<span class="logo" style="background-image:url('${esc(cssUrl(c.logo))}')"></span>` : `<span class="logo none">${esc(initials(c.name))}</span>`}
            <div class="main"><b>#${c.id} · ${esc(c.name)}</b> ${c.enabled ? '<span class="pill on">Active</span>' : `<span class="pill bad">Suspendue${c.reason ? ` : ${esc(c.reason)}` : ''}</span>`}
              <small>${esc(c.specialtyIcon || '')} ${esc(c.specialtyLabel || '')} · fondateur ${esc(c.owner || '?')} (${esc(c.ownerCid || '')}) · ${c.employees} employé(s) · compte ${money(c.balance)} · ${esc(c.job)}</small>
              <p class="desc">${esc(c.description || '')}</p></div></div>
          <div class="actions-row">
            <button class="btn small ${c.enabled ? 'danger' : 'primary'}" data-ad="${c.enabled ? 'suspend' : 'enable'}" data-id="${c.id}">${c.enabled ? 'Suspendre' : 'Réactiver'}</button>
            <button class="btn small" data-ad="logo" data-id="${c.id}" ${c.logo ? '' : 'disabled'}>Retirer le logo</button>
            <button class="btn small" data-ad="desc" data-id="${c.id}">Retirer la description</button>
            <button class="btn small" data-ad="rename" data-id="${c.id}">Renommer</button>
            <button class="btn small danger" data-ad="dissolve" data-id="${c.id}">Dissoudre</button></div></div>`).join('') || '<div class="empty">Aucune entreprise.</div>'}</div>`;
  }
  async function reload() { const r = await adm('list'); if (!r.error) { A.list = r.list || []; draw(); } else toast(r.error, false); }
  async function run(action, data) {
    const r = await adm(action, data);
    if (r.error) toast(r.error, false); else if (r.message) toast(r.message, true);
    if (r.ok) await reload();
  }
  document.addEventListener('input', (e) => { if (e.target.id === 'adQ') { A.q = e.target.value; const pos = e.target.selectionStart; draw(); const i = $('#adQ'); i.focus(); i.setSelectionRange(pos, pos); } });
  document.addEventListener('click', async (e) => {
    const b = e.target.closest('#admin [data-ad]');
    if (!b) return;
    const a = b.dataset.ad, id = Number(b.dataset.id), c = A.list.find((x) => x.id === id);
    if (a === 'close') return post('close', { ui: 'admin' });
    if (a === 'enable') return run('toggle', { id, enabled: true });
    if (a === 'suspend') {
      const v = await confirmBox(`Suspendre « ${c.name} » ?`, 'Plus d\'appels, de messages ni de service ; l\'entreprise disparaît de l\'appli Entreprises. Le patron voit le motif.', 'Suspendre', true,
        '<label class="field" style="margin-top:.6rem"><span>Motif</span><input class="input" data-cfv="reason" maxlength="160"></label>');
      if (v) run('toggle', { id, enabled: false, reason: v.reason });
      return;
    }
    if (a === 'logo') { if (await confirmBox('Retirer le logo ?', `Le logo de « ${esc(c.name)} » sera supprimé.`, 'Retirer', true)) run('clear', { id, logo: true }); return; }
    if (a === 'desc') { if (await confirmBox('Retirer la description ?', `Remplacée par « Description retirée par le staff. »`, 'Retirer', true)) run('clear', { id, description: true }); return; }
    if (a === 'rename') {
      const v = await confirmBox('Renommer', `Nom actuel : <b>${esc(c.name)}</b>`, 'Renommer', false, `<label class="field" style="margin-top:.6rem"><span>Nouveau nom</span><input class="input" data-cfv="name" maxlength="40" value="${esc(c.name)}"></label>`);
      if (v) run('rename', { id, name: v.name });
      return;
    }
    if (a === 'dissolve') {
      const v = await confirmBox(`Dissoudre « ${c.name} » ?`, `Tous les employés perdent ce métier. Le solde (${money(c.balance)}) est versé au fondateur. <b>Définitif.</b>`, 'Dissoudre', true,
        '<label class="field" style="margin-top:.6rem"><span>Motif</span><input class="input" data-cfv="reason" maxlength="160"></label>');
      if (v) run('dissolve', { id, reason: v.reason });
    }
  });
  window.Admin = {
    open(data) { A.open = true; A.list = (data && data.list) || []; $('#admin').classList.remove('hidden'); draw(); },
    hide() { A.open = false; $('#admin').classList.add('hidden'); },
    isOpen: () => A.open,
  };
})();
