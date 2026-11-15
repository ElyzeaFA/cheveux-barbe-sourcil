/* =========================================================
   LETTRES (ressource elyzea_lettres, permission « lettres_manage »)
   Réglages de la correspondance : longueur, pages, styles d'écriture, papiers,
   consommation des feuilles, enveloppes, animation. Dernières lettres écrites
   (auteur, destinataire, date, pages) — le contenu reste privé.
   ========================================================= */
(() => {
    TABS.push({
        id: 'lettres', group: 4, label: 'Lettres', ico: '✉️',
        sub: 'Correspondance des joueurs : feuille + stylo pour écrire, lettres à donner, ranger, mettre sous enveloppe.',
        show: () => has('lettres_manage') && !!(D && D.lettres),
    });

    const S = { draft: null };
    const send = (name, data = {}) => action('lettres', { name, data });
    const later = () => setTimeout(() => post('refresh'), 500);
    const CONSUME = [['letter', '1 feuille par lettre'], ['page', '1 feuille par page écrite'], ['none', 'Aucune (il faut quand même une feuille sur soi)']];

    VIEWS.lettres = () => {
        const d = D.lettres;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_lettres')}</b> ne répond pas : vérifie
                <span class="keycap">ensure ${esc(d.resource || 'elyzea_lettres')}</span> dans server.cfg (après elyzea_inventory et admin_menu).</span></div>`;
        }
        if (!S.draft) S.draft = JSON.parse(JSON.stringify(d.settings));
        const s = S.draft, L = d.limits || {}, st = d.stats || {}, it = d.items || {};
        const toggle = (key, on, title, text) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-ltg="${key}"><div><strong>${title}</strong><span>${text}</span></div><div class="switch"></div></div>`;
        return `
            <div class="stats">
                <div class="stat"><b>${st.total || 0}</b><span>Lettres écrites</span></div>
                <div class="stat"><b>${st.today || 0}</b><span>Aujourd'hui</span></div>
                <div class="stat"><b>${st.week || 0}</b><span>Ces 7 derniers jours</span></div>
            </div>
            <div class="section"><h2>✉️ Réglages</h2>
                <p class="hint">Objets : <b>${esc(it.paper)}</b> (feuille), <b>${esc(it.pen)}</b> (stylo), <b>${esc(it.letter)}</b> (lettre),
                    <b>${esc(it.envelope)}</b> (enveloppe vide), <b>${esc(it.sealed)}</b> (enveloppe avec lettre). Une lettre terminée n'est jamais modifiable.
                    Les réglages s'appliquent aux prochaines feuilles ouvertes.</p>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(3,minmax(200px,1fr));gap:12px;max-width:980px;margin-bottom:12px">
                    <div class="field"><label>Caractères maximum par lettre</label><input class="input" type="number" data-lnum="maxChars" value="${esc(s.maxChars)}" min="${(L.maxChars || [])[0]}" max="${(L.maxChars || [])[1]}">
                        <span class="muted" style="font-size:11px">${(L.maxChars || [])[0]} à ${(L.maxChars || [])[1]} · environ 800 par page pleine</span></div>
                    <div class="field"><label>Pages maximum par lettre</label><input class="input" type="number" data-lnum="maxPages" value="${esc(s.maxPages)}" min="${(L.maxPages || [])[0]}" max="${(L.maxPages || [])[1]}">
                        <span class="muted" style="font-size:11px">${(L.maxPages || [])[0]} à ${(L.maxPages || [])[1]}</span></div>
                    <div class="field"><label>Consommation des feuilles</label><select class="input" data-lsel="consume">
                        ${CONSUME.map(([k, l]) => `<option value="${k}" ${s.consume === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
                        <span class="muted" style="font-size:11px">Jamais consommée si la lettre est annulée.</span></div>
                </div>
                <h3 style="margin:14px 0 8px">Styles d'écriture</h3>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(230px,1fr));margin-bottom:8px">
                    ${(d.fonts || []).map((f) => toggle(`font:${f.id}`, s.fonts[f.id], f.label, s.defaultFont === f.id ? 'Style proposé par défaut' : 'Clic droit : style par défaut')).join('')}
                </div>
                <h3 style="margin:14px 0 8px">Papiers</h3>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(230px,1fr));margin-bottom:8px">
                    ${(d.papers || []).map((p) => toggle(`paper:${p.id}`, s.papers[p.id], p.label, 'Proposé à l\'écriture')).join('')}
                </div>
                <h3 style="margin:14px 0 8px">Options</h3>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${toggle('envelopes', s.envelopes, s.envelopes ? 'Enveloppes activées' : 'Enveloppes coupées', 'Mettre une lettre sous enveloppe cachetée, avec le destinataire écrit dessus.')}
                    ${toggle('animation', s.animation, s.animation ? 'Animation activée' : 'Animation coupée', 'Le personnage écrit sur un carnet / tient la lettre en la lisant.')}
                </div>
                <div class="btn-row"><button class="btn primary" data-lact="save">Enregistrer</button><button class="btn" data-lact="undo">Annuler les changements</button>
                    <button class="btn danger" data-lact="reset">Valeurs par défaut</button></div>
            </div>
            <div class="section"><h2>Dernières lettres</h2>
                <p class="hint">Le contenu des lettres reste privé. L'identifiant permet de retrouver une lettre en base (table <b>elyzea_letters</b>) en cas de signalement.</p>
                ${(d.recent || []).length ? `<table><tr><th>Lettre</th><th>Date</th><th>Auteur</th><th>Destinataire</th><th>Pages</th><th>Style</th></tr>
                    ${d.recent.map((r) => `<tr><td class="muted">${esc(r.id)}</td><td>${esc(r.created)}</td><td><strong>${esc(r.author_name || '?')}</strong><br><span class="muted">${esc(r.author_cid || '')}</span></td>
                        <td>${esc(r.recipient || '—')}</td><td>${esc(r.pages)}</td><td>${esc(r.font)}</td></tr>`).join('')}</table>` : '<div class="empty">Aucune lettre écrite pour l\'instant.</div>'}
            </div>`;
    };

    const on = () => isOpen && tab === 'lettres' && D && D.lettres && D.lettres.available && S.draft;
    document.addEventListener('input', (ev) => { if (on() && ev.target.dataset.lnum) S.draft[ev.target.dataset.lnum] = Number(ev.target.value); });
    document.addEventListener('change', (ev) => { if (on() && ev.target.dataset.lsel) S.draft[ev.target.dataset.lsel] = ev.target.value; });
    document.addEventListener('contextmenu', (ev) => {
        if (!on()) return;
        const t = ev.target.closest('[data-ltg^="font:"]');
        if (!t) return;
        ev.preventDefault();
        const id = t.dataset.ltg.slice(5);
        S.draft.fonts[id] = true; S.draft.defaultFont = id; render();
    });
    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        let n;
        if ((n = ev.target.closest('[data-ltg]'))) {
            const [k, id] = n.dataset.ltg.split(':');
            if (k === 'font') S.draft.fonts[id] = !S.draft.fonts[id];
            else if (k === 'paper') S.draft.papers[id] = !S.draft.papers[id];
            else S.draft[k] = !S.draft[k];
            return render();
        }
        if (!(n = ev.target.closest('[data-lact]'))) return;
        const a = n.dataset.lact;
        if (a === 'save') { send('save', S.draft); S.draft = null; return later(); }
        if (a === 'undo') { S.draft = null; return render(); }
        if (a === 'reset' && await confirmBox('Valeurs par défaut ?', 'Les réglages des lettres reviennent à ceux de config.lua.')) { send('reset'); S.draft = null; later(); }
    });
})();
