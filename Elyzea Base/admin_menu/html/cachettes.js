/* =========================================================
   CACHETTES VÉHICULES (ressource elyzea_cachettes, permission « cachettes_manage »)
   Catégories de véhicules, capacité de chaque emplacement, emplacements autorisés,
   mini-jeux (difficulté, durée, erreurs, temps), inspection policière, permissions,
   objets interdits ; recherche des cachettes d'un véhicule par plaque.
   ========================================================= */
(() => {
    TABS.push({
        id: 'cachettes', group: 2, label: 'Cachettes véhicules', ico: '🪛',
        sub: 'Contrebande : cachettes dans les véhicules, mini-jeux au tournevis, suspicion et fouille policière.',
        show: () => has('cachettes_manage') && !!(D && D.cachettes),
    });

    const CA = { draft: null, plate: '' };
    const send = (name, data = {}) => action('cachettes', { name, data });
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const CAT_OPTS = [['none', 'Aucune cachette'], ['small', 'Petit'], ['medium', 'Moyen'], ['large', 'SUV / grand'], ['moto', 'Moto / scooter']];
    const TYPE_L = { door: 'Chaque portière', trunk: 'Coffre', wheel: 'Chaque passage de roue', seat: 'Chaque siège', saddle: 'Sous la selle' };
    const SUSP = ['Aucune', 'Légère', 'Élevée'];

    function draft() {
        const d = D.cachettes;
        if (!CA.draft) CA.draft = clone({ categories: d.categories, classes: d.classes, models: d.models, games: d.games, access: d.access,
            minSeconds: d.minSeconds, inspect: d.inspect, blacklist: d.blacklist });
        return CA.draft;
    }
    const sel = (path, val, opts) => `<select class="input" data-cap="${path}">${opts.map(([v, l]) => `<option value="${v}" ${String(v) === String(val) ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select>`;
    const num = (path, val, min, max, step = 1, w = 90) => `<input class="input" type="number" min="${min}" max="${max}" step="${step}" data-cap="${path}" value="${esc(val)}" style="width:${w}px">`;
    const chk = (path, val) => `<input type="checkbox" data-cap="${path}" ${val ? 'checked' : ''}>`;
    const txtIn = (path, val, w = '100%') => `<input class="input" type="text" data-cap="${path}" value="${esc(val)}" style="width:${w}">`;

    VIEWS.cachettes = () => {
        const d = D.cachettes;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_cachettes')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        const r = draft();
        const caps = r.categories.map((c, i) => `<tr><td><strong>${esc(c.label)}</strong></td>${['door', 'trunk', 'wheel', 'seat', 'saddle'].map((t) =>
            `<td>${c.caps[t] !== undefined ? `${num(`categories.${i}.caps.${t}`, c.caps[t], 0, 500, 0.5, 80)} <span class="muted" style="font-size:11px">kg</span>` : '<span class="muted">—</span>'}</td>`).join('')}</tr>`).join('');
        const classes = r.classes.map((c, i) => `<tr><td>${esc(c.label)} <span class="muted" style="font-size:11px">(classe ${c.class})</span></td><td>${sel(`classes.${i}.category`, c.category, CAT_OPTS)}</td></tr>`).join('');
        const models = r.models.map((m, i) => `<tr><td>${txtIn(`models.${i}.model`, m.model, '180px')}</td><td>${sel(`models.${i}.category`, m.category, CAT_OPTS)}</td><td style="text-align:right"><button class="btn" data-caa="model_rm" data-i="${i}">Retirer</button></td></tr>`).join('');
        const games = r.games.map((g, i) => `<tr><td>${chk(`games.${i}.enabled`, g.enabled)} <strong>${esc(TYPE_L[g.type] || g.label)}</strong><div class="muted" style="font-size:11px">${esc(g.game)}</div></td>
            <td>${num(`games.${i}.difficulty`, g.difficulty, 1, 5)}</td><td>${num(`games.${i}.length`, g.length, 0.6, 1.6, 0.1)}</td><td>${num(`games.${i}.maxErrors`, g.maxErrors, 1, 10)}</td><td>${num(`games.${i}.timeLimit`, g.timeLimit, 90, 600, 10)}</td></tr>`).join('');
        const L = d.lookup;
        const look = L ? `<p class="hint">Véhicule <b>${esc(L.plate)}</b> · ${esc(L.model || '?')} · n° ${L.vehicleId} · propriétaire ${esc(L.owner || '?')}</p>
            ${L.list.length ? `<table class="loot wide"><tr><th>Emplacement</th><th>État</th><th>Essais</th><th>Suspicion</th><th>Capacité</th><th>Objets</th><th></th></tr>
            ${L.list.map((c) => `<tr><td>${esc(c.label)}</td><td>${c.state === 1 ? (c.discovered ? 'Installée · <span style="color:var(--warn)">découverte par la police</span>' : 'Installée') : 'Installation non terminée'}</td>
                <td>${c.state === 1 ? c.attempts + 1 : c.attempts + ' raté(s)'}</td><td>${c.state === 1 ? SUSP[c.suspicion] || '?' : '—'}</td><td>${c.state === 1 ? `${c.capacity} kg` : '—'}</td><td>${c.items}</td>
                <td style="text-align:right"><button class="btn" data-caa="delete" data-veh="${L.vehicleId}" data-slot="${esc(c.slot)}" ${c.items > 0 || c.busy ? 'disabled' : ''}>Supprimer</button></td></tr>`).join('')}</table>`
            : '<p class="muted">Aucune cachette sur ce véhicule.</p>'}` : '';
        return `
            <div class="stats">
                <div class="stat"><b>${d.installed}</b><span>Cachettes installées</span></div>
                <div class="stat"><b>${esc(d.tool)}</b><span>Objet nécessaire</span></div>
            </div>
            <div class="section"><h2>🔎 Cachettes d'un véhicule</h2>
                <div class="btn-row"><input class="input" id="caPlate" type="text" placeholder="Plaque" value="${esc(CA.plate)}" style="width:180px"><button class="btn primary" data-caa="lookup">Rechercher</button></div>
                ${look}
            </div>
            <div class="section"><h2>⚖️ Capacité de chaque emplacement (kg)</h2>
                <p class="hint">Chaque emplacement a sa propre capacité : aucune capacité n'est partagée entre deux cachettes. La capacité est fixée à l'installation : un changement s'applique aux nouvelles cachettes.</p>
                <table class="loot wide"><tr><th>Catégorie</th><th>Chaque portière</th><th>Coffre</th><th>Chaque roue</th><th>Chaque siège</th><th>Sous la selle</th></tr>${caps}</table>
            </div>
            <div class="section"><h2>🚗 Catégorie par classe de véhicule</h2>
                <p class="hint">Les emplacements proposés sont ceux qui existent vraiment sur le modèle (portières, roues, coffre, sièges) ; les motos et scooters n'ont que le compartiment sous la selle.</p>
                <table class="loot wide"><tr><th>Classe</th><th style="width:220px">Catégorie</th></tr>${classes}</table>
                <h2 style="margin-top:14px">Exceptions par modèle</h2>
                <table class="loot wide"><tr><th>Nom de spawn</th><th>Catégorie</th><th></th></tr>${models || '<tr><td colspan="3" class="muted">Aucune exception.</td></tr>'}</table>
                <div class="btn-row" style="margin-top:8px"><button class="btn" data-caa="model_add">Ajouter un modèle</button></div>
            </div>
            <div class="section"><h2>🪛 Emplacements et mini-jeux</h2>
                <p class="hint">Le même mini-jeu sert à l'installation, à l'ouverture et à la fouille policière. <b>Difficulté</b> 1 à 5 · <b>Durée</b> 0,6 à 1,6 (nombre de fixations) · <b>Erreurs</b> tolérées avant l'échec · <b>Temps</b> limite en secondes. Décocher un type le retire de tous les véhicules.</p>
                <table class="loot wide"><tr><th>Emplacement</th><th>Difficulté</th><th>Durée</th><th>Erreurs</th><th>Temps (s)</th></tr>${games}</table>
                <p class="hint">Anti-triche : une réussite plus rapide que ${num('minSeconds', r.minSeconds, 0, 120)} s × durée est refusée.</p>
            </div>
            <div class="section"><h2>🚓 Police et accès</h2>
                <table class="loot wide">
                    <tr><td>Permission de grade police pour « Inspecter le véhicule »</td><td>${txtIn('access.policeInspectPerm', r.access.policeInspectPerm, '200px')}</td></tr>
                    <tr><td>Permission de grade police pour démonter et saisir</td><td>${txtIn('access.policeOpenPerm', r.access.policeOpenPerm, '200px')}</td></tr>
                    <tr><td>La police doit aussi avoir un tournevis</td><td>${chk('access.policeNeedsTool', r.access.policeNeedsTool)}</td></tr>
                    <tr><td>Les civils doivent avoir les clés du véhicule</td><td>${chk('access.requireKeys', r.access.requireKeys)}</td></tr>
                    <tr><td>Durée de l'inspection (ms)</td><td>${num('inspect.duration', r.inspect.duration, 3000, 60000, 500, 110)}</td></tr>
                    <tr><td>Message · suspicion légère (<code>%s</code> = emplacement)</td><td>${txtIn('inspect.light', r.inspect.light)}</td></tr>
                    <tr><td>Message · suspicion élevée (<code>%s</code> = emplacement)</td><td>${txtIn('inspect.high', r.inspect.high)}</td></tr>
                    <tr><td>Message · aucune anomalie</td><td>${txtIn('inspect.none', r.inspect.none)}</td></tr>
                </table>
                <p class="hint">Permissions de grade dans la tablette police › Direction › Grades : <b>veh_inspect</b> (inspecter) et <b>veh_cachettes</b> (démonter, saisir).</p>
            </div>
            <div class="section"><h2>⛔ Objets interdits dans les cachettes</h2>
                <p class="hint">Noms d'objets de l'inventaire, séparés par des virgules (ex. <code>WEAPON_RPG, bank_drill</code>).</p>
                ${txtIn('blacklistText', r.blacklist.join(', '))}
            </div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-caa="save">Enregistrer les réglages</button><button class="btn" data-caa="cancel">Annuler les modifications</button><button class="btn" data-caa="reset">Valeurs par défaut</button></div>`;
    };

    function setPath(obj, path, val) {
        const ks = path.split('.'); let o = obj;
        for (let i = 0; i < ks.length - 1; i++) o = o[ks[i]];
        o[ks[ks.length - 1]] = val;
    }
    function onEdit(e) {
        const el = e.target.closest('[data-cap]');
        if (!el || !CA.draft) return;
        const p = el.dataset.cap;
        let v = el.type === 'checkbox' ? el.checked : (el.type === 'number' ? Number(el.value) : el.value);
        if (p === 'blacklistText') { CA.draft.blacklist = String(v).split(',').map((s) => s.trim()).filter(Boolean); return; }
        setPath(CA.draft, p, v);
    }
    document.addEventListener('input', (e) => { if (tab === 'cachettes') onEdit(e); });
    document.addEventListener('change', (e) => { if (tab === 'cachettes') onEdit(e); });
    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'cachettes') return;
        const n = e.target.closest('[data-caa]');
        if (!n || n.disabled) return;
        const a = n.dataset.caa;
        if (a === 'lookup') { CA.plate = ($('#caPlate') || {}).value || ''; send('lookup', { plate: CA.plate }); }
        else if (a === 'delete') {
            if (!(await confirmBox('Supprimer la cachette ?', 'Elle est vide : elle disparaîtra du véhicule (la suspicion avec).'))) return;
            send('delete', { vehicleId: Number(n.dataset.veh), slot: n.dataset.slot });
        } else if (a === 'model_add') { draft().models.push({ model: '', category: 'none' }); render(); }
        else if (a === 'model_rm') { draft().models.splice(Number(n.dataset.i), 1); render(); }
        else if (a === 'save') { const r = draft(); send('save', { ...r, models: r.models.filter((m) => m.model.trim() !== '') }); CA.draft = null; }
        else if (a === 'cancel') { CA.draft = null; render(); }
        else if (a === 'reset') {
            if (!(await confirmBox('Valeurs par défaut ?', 'Tous les réglages des cachettes reviennent à ceux de config.lua (les cachettes déjà installées sont gardées).'))) return;
            CA.draft = null; send('reset');
        }
    });
})();
