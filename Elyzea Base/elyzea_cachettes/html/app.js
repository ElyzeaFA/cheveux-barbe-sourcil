/* =====================================================================
   ELYZEA CACHETTES - interface : choix de l'emplacement et déroulé du mini-jeu
   Le résultat (réussite, échec, annulation, erreurs) est renvoyé au client Lua,
   qui le transmet au serveur ; le serveur vérifie la durée réelle et le reste.
   ===================================================================== */
(() => {
    const $ = (s) => document.querySelector(s);
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_cachettes';
    window.__posts = [];
    function post(name, data = {}) {
        window.__posts.push({ name, data });
        return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
    }
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const ICON = { door: '🚪', trunk: '🧳', wheel: '🛞', seat: '💺', saddle: '🏍️' };
    const MODE = { install: 'Aménagement d\'une cachette', open: 'Ouverture de la cachette', search: 'Fouille policière' };

    // ------------------------------------------------------------- choix de l'emplacement
    let pickerOpen = false;
    function showPicker(m) {
        pickerOpen = true;
        $('#pkTitle').textContent = m.role === 'police' ? 'Démonter un emplacement' : 'Cacher un objet de contrebande';
        $('#pkSub').textContent = [m.plate && `Plaque ${m.plate}`, m.category].filter(Boolean).join(' · ');
        $('#pkList').innerHTML = (m.slots || []).map((s) => {
            let chip = '';
            if (m.role === 'police') chip = '<span class="chip">Démonter</span>';
            else if (s.status === 'installed') chip = `<span class="chip ok">Cachette · ${esc(s.capacity)} kg</span>`;
            else chip = `<span class="chip ${s.attempts ? 'warn' : ''}">Libre · ${esc(s.capacity)} kg${s.attempts ? ` · ${s.attempts} essai(s) raté(s)` : ''}</span>`;
            const action = m.role === 'police' ? '' : (s.status === 'installed' ? 'Ouvrir' : 'Installer');
            return `<button class="slot" data-slot="${esc(s.id)}" ${s.disabled ? 'disabled' : ''}>
                <span class="ico">${ICON[s.type] || '•'}</span>
                <span><b>${action ? `${action} · ` : ''}${esc(s.label)}</b><small>${esc(s.desc || s.game || '')}</small></span>${chip}</button>`;
        }).join('');
        $('#picker').classList.remove('hidden');
        const first = $('#pkList .slot:not(:disabled)');
        if (first) first.focus();
    }
    function hidePicker() { pickerOpen = false; $('#picker').classList.add('hidden'); }
    $('#pkList').addEventListener('click', (e) => {
        const b = e.target.closest('.slot');
        if (!b || b.disabled || !pickerOpen) return;
        hidePicker();
        post('pick', { slot: b.dataset.slot });
    });
    $('[data-close]').addEventListener('click', () => { if (pickerOpen) { hidePicker(); post('close'); } });

    // ------------------------------------------------------------- mini-jeu
    const cv = $('#cv'), g = cv.getContext('2d');
    let run = null;   // partie en cours

    function errPips() {
        const r = run; if (!r) return;
        let h = ''; for (let i = 0; i < r.maxErrors; i++) h += `<i class="${i < r.errors ? 'on' : ''}"></i>`;
        h += ` <small>(${r.maxErrors} tolérée${r.maxErrors > 1 ? 's' : ''})</small>`;
        $('#gErr').innerHTML = h;
    }
    function steps() {
        const r = run; if (!r) return;
        $('#gSteps').innerHTML = r.phases.map((p, i) => `<div class="${i < r.idx ? 'done' : (i === r.idx ? 'on' : '')}">${i < r.idx ? '✓' : i + 1}. ${esc(p.title)}</div>`).join('');
        const p = r.phases[r.idx];
        $('#gHint').textContent = p ? p.hint : '';
    }
    let toastT = 0;
    function toast(text, bad) {
        const t = $('#gToast'); t.textContent = text; t.className = `toast${bad ? ' bad' : ''}`; toastT = performance.now() + 1600;
    }
    function card(title, sub, cls = '') {
        $('#gCardT').textContent = title; $('#gCardS').textContent = sub || '';
        $('#gCard').className = `overlay ${cls}`;
    }
    function fmt(s) { s = Math.max(0, Math.floor(s)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; }

    function startGame(m) {
        const factory = window.CachGames[m.game];
        if (!factory) { post('result', { cancelled: true }); return; }
        const p = m.params || {};
        const r = {
            game: m.game, maxErrors: Math.max(1, Number(p.maxErrors) || 4), timeLimit: Math.max(30, Number(p.timeLimit) || 180),
            errors: 0, idx: 0, t: 0, elapsed: 0, intro: 1.2, ended: false, phaseDone: false, last: performance.now(), mx: 0, my: 0,
        };
        const ctx = {
            params: p, rng: window.CachGames.rng(Number(p.seed) || Date.now()),
            error(msg) {
                if (r.ended || r !== run) return;
                r.errors++; errPips(); toast(msg || 'Erreur', true);
                const st = $('.stage'); st.classList.remove('flash'); void st.offsetWidth; st.classList.add('flash');
                post('progress', { errors: r.errors });
                if (r.errors > r.maxErrors) finish(false, 'Trop d\'erreurs : le démontage a échoué.');
            },
            done() { if (!r.ended && r === run && !r.phaseDone) { r.phaseDone = true; r.nextAt = r.t + 0.6; } },
            toast(msg) { if (r === run) toast(msg, false); },
        };
        r.phases = factory(ctx);
        run = r;
        $('#gTitle').textContent = m.label || 'Cachette';
        $('#gSub').textContent = MODE[m.mode] || '';
        $('#gLimit').textContent = `limite ${fmt(r.timeLimit)}`;
        $('#game').classList.remove('hidden');
        $('#gToast').className = 'toast hidden';
        errPips(); steps(); beginPhase();
        requestAnimationFrame(loop);
    }
    function beginPhase() {
        const r = run; const p = r.phases[r.idx];
        r.intro = 1.2; r.phaseDone = false;
        if (p.init) p.init();
        card(`Étape ${r.idx + 1} / ${r.phases.length}`, p.title);
        steps();
    }
    function finish(success, why) {
        const r = run; if (!r || r.ended) return;
        r.ended = true;
        card(success ? 'Compartiment ouvert' : 'Échec', success ? 'Accès à la cachette…' : why, success ? 'ok' : 'bad');
        setTimeout(() => {
            if (run !== r) return;
            run = null;
            $('#game').classList.add('hidden');
            post('result', { success, errors: r.errors, elapsed: Math.round(r.elapsed * 1000) });
        }, success ? 700 : 1600);
    }
    function cancel() {
        const r = run; if (!r || r.ended) return;
        r.ended = true; run = null;
        $('#game').classList.add('hidden');
        post('result', { cancelled: true, errors: r.errors });
    }
    window.__cach = { get run() { return run; }, finish, cancel };

    function loop(now) {
        const r = run; if (!r) return;
        const dt = Math.min(0.05, (now - r.last) / 1000); r.last = now;
        if (!r.ended) {
            r.elapsed += dt;
            const left = r.timeLimit - r.elapsed;
            $('#gTime').textContent = fmt(r.elapsed);
            $('.timer').classList.toggle('low', left < 20);
            if (left <= 0) finish(false, 'Temps écoulé.');
        }
        const p = r.phases[r.idx];
        if (r.intro > 0) {
            r.intro -= dt;
            if (r.intro <= 0) $('#gCard').className = 'overlay hidden';
        } else if (!r.ended) {
            r.t += dt;
            if (!r.phaseDone) p.update(dt, r.t);
            else if (r.t >= r.nextAt) {
                r.idx++;
                if (r.idx >= r.phases.length) { r.idx = r.phases.length - 1; steps(); finish(true); } else beginPhase();
            }
        }
        const cur = r.phases[r.idx];
        g.clearRect(0, 0, cv.width, cv.height);
        cur.draw(g, r.t);
        const prog = (r.idx + (r.phaseDone ? 1 : clamp01(cur.progress()))) / r.phases.length;
        $('#gProg').style.width = `${Math.round(prog * 100)}%`;
        if (toastT && now > toastT) { $('#gToast').className = 'toast hidden'; toastT = 0; }
        requestAnimationFrame(loop);
    }
    const clamp01 = (v) => Math.max(0, Math.min(1, Number(v) || 0));
    const live = () => run && !run.ended && run.intro <= 0 && !run.phaseDone ? run.phases[run.idx] : null;

    // ------------------------------------------------------------- entrées
    function pos(e) { const b = cv.getBoundingClientRect(); return [(e.clientX - b.left) * (cv.width / b.width), (e.clientY - b.top) * (cv.height / b.height)]; }
    let lastMove = performance.now();
    cv.addEventListener('mousedown', (e) => { const p = live(); if (!p || e.button !== 0) return; const [x, y] = pos(e); run.mx = x; run.my = y; if (p.down) p.down(x, y); });
    window.addEventListener('mouseup', (e) => { const p = live(); if (!p || e.button !== 0) return; const [x, y] = pos(e); if (p.up) p.up(x, y); });
    window.addEventListener('mousemove', (e) => {
        if (!run) return; const [x, y] = pos(e); const now = performance.now(); const dt = (now - lastMove) / 1000; lastMove = now;
        const dx = x - run.mx, dy = y - run.my; run.mx = x; run.my = y;
        const p = live(); if (p && p.move) p.move(x, y, dx, dy, dt);
    });
    cv.addEventListener('wheel', (e) => { e.preventDefault(); const p = live(); if (p && p.wheel) p.wheel(e.deltaY); }, { passive: false });
    cv.addEventListener('contextmenu', (e) => e.preventDefault());
    const held = new Set();
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (pickerOpen) { hidePicker(); post('close'); } else if (run) cancel();
            return;
        }
        if (pickerOpen) {
            const list = [...document.querySelectorAll('#pkList .slot:not(:disabled)')];
            const i = list.indexOf(document.activeElement);
            if (e.key === 'ArrowDown') { e.preventDefault(); (list[i + 1] || list[0])?.focus(); }
            if (e.key === 'ArrowUp') { e.preventDefault(); (list[i - 1] || list[list.length - 1])?.focus(); }
            return;
        }
        const k = e.key === ' ' ? ' ' : e.key.toLowerCase();
        if (k === ' ') e.preventDefault();
        if (held.has(k)) return;   // pas de répétition automatique du clavier
        held.add(k);
        const p = live(); if (p && p.key) p.key(k, true);
    });
    window.addEventListener('keyup', (e) => {
        const k = e.key === ' ' ? ' ' : e.key.toLowerCase();
        held.delete(k);
        const p = live(); if (p && p.key) p.key(k, false);
    });
    window.addEventListener('blur', () => { held.clear(); });

    // ------------------------------------------------------------- messages du client Lua
    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action === 'slots') showPicker(m);
        else if (m.action === 'game') { hidePicker(); startGame(m); }
        else if (m.action === 'abort') { if (run) { run.ended = true; run = null; } $('#game').classList.add('hidden'); }
        else if (m.action === 'hide') { hidePicker(); if (!run) $('#game').classList.add('hidden'); }
    });
})();
