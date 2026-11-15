/* =====================================================================
   ELYZEA CACHETTES - mini-jeux (un par type d'emplacement, 3 étapes chacun)
   Chaque étape a sa propre mécanique ; aucune n'est réutilisée d'un emplacement à l'autre.
     Portière : vis (aiguille tournante) · clips (dosage de force) · dépose du panneau (glisser lentement)
     Coffre   : rivets (mémoire) · vis à embouts (bon embout + tenue) · loquets (recherche du cran)
     Roue     : écrous (couple dans la zone) · agrafes cachées (lampe) · pare-boue (pompage à la molette)
     Siège    : glissières (rythme) · agrafes (pince) · couture (suivre le fil sans déchirer)
     Selle    : serrure (goupilles) · coque (dévissage circulaire) · bac (équilibre)
   difficulty (1-5) resserre les tolérances et accélère ; length (0.6-1.6) change le nombre de fixations.
   ===================================================================== */
(() => {
    const W = 760, H = 420;
    const TAU = Math.PI * 2;
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const lerp = (a, b, t) => a + (b - a) * t;
    const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);
    const angDiff = (a, b) => { let d = (a - b) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return d; };
    const C = { bg: '#120d1c', panel: '#1d1530', panel2: '#271c40', line: '#3a2b5c', violet: '#9b5cff', violet2: '#c9a6ff',
        ok: '#3ddc97', warn: '#ffb347', bad: '#ff4d6d', text: '#efe7ff', mute: '#9a8cb8', metal: '#b9b4c4', dark: '#0b0812' };

    function rng(seed) {
        let a = (seed >>> 0) || 1;
        const f = () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
        f.range = (x, y) => x + f() * (y - x);
        f.int = (x, y) => Math.floor(x + f() * (y - x + 1));
        return f;
    }
    function tune(p) {
        const d = clamp(Number(p.difficulty) || 3, 1, 5);
        return { d, tol: 1.25 - 0.1 * (d - 1), sp: 0.85 + 0.075 * (d - 1), L: clamp(Number(p.length) || 1, 0.6, 1.6) };
    }
    const count = (base, L, min = 2) => Math.max(min, Math.round(base * L));

    // ---------- dessin ----------
    function rr(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
    function bg(g, a = C.panel, b = C.bg) { const gr = g.createLinearGradient(0, 0, 0, H); gr.addColorStop(0, a); gr.addColorStop(1, b); g.fillStyle = gr; g.fillRect(0, 0, W, H); }
    function txt(g, s, x, y, o = {}) { g.font = `${o.w || 600} ${o.size || 14}px Inter, Segoe UI, sans-serif`; g.fillStyle = o.color || C.text; g.textAlign = o.align || 'left'; g.textBaseline = o.base || 'middle'; g.fillText(s, x, y); }
    function circle(g, x, y, r, fill, stroke, lw = 2) { g.beginPath(); g.arc(x, y, r, 0, TAU); if (fill) { g.fillStyle = fill; g.fill(); } if (stroke) { g.strokeStyle = stroke; g.lineWidth = lw; g.stroke(); } }
    function screwHead(g, x, y, r, rot, kind = 'cross') {
        const gr = g.createRadialGradient(x - r * 0.3, y - r * 0.3, r * 0.1, x, y, r);
        gr.addColorStop(0, '#f2f0f6'); gr.addColorStop(1, '#6f6a7d');
        circle(g, x, y, r, gr, '#2a2533', 1.5);
        g.save(); g.translate(x, y); g.rotate(rot); g.strokeStyle = '#2a2533'; g.lineWidth = Math.max(2, r * 0.22); g.lineCap = 'round';
        g.beginPath();
        if (kind === 'flat') { g.moveTo(-r * 0.6, 0); g.lineTo(r * 0.6, 0); }
        else if (kind === 'hex') { for (let i = 0; i <= 6; i++) { const a = i / 6 * TAU; const px = Math.cos(a) * r * 0.5, py = Math.sin(a) * r * 0.5; i ? g.lineTo(px, py) : g.moveTo(px, py); } }
        else if (kind === 'torx') { for (let i = 0; i <= 12; i++) { const a = i / 12 * TAU; const rr2 = (i % 2 ? 0.28 : 0.55) * r; const px = Math.cos(a) * rr2, py = Math.sin(a) * rr2; i ? g.lineTo(px, py) : g.moveTo(px, py); } }
        else { g.moveTo(-r * 0.55, 0); g.lineTo(r * 0.55, 0); g.moveTo(0, -r * 0.55); g.lineTo(0, r * 0.55); }
        g.stroke(); g.restore();
    }
    function gauge(g, x, y, w, h, v, zones = []) {
        rr(g, x, y, w, h, 6); g.fillStyle = C.dark; g.fill();
        for (const z of zones) { g.fillStyle = z.c; g.fillRect(x + w * z.a, y + 2, w * (z.b - z.a), h - 4); }
        g.fillStyle = C.violet2; g.fillRect(x + w * clamp(v, 0, 1) - 2, y - 4, 4, h + 8);
        rr(g, x, y, w, h, 6); g.strokeStyle = C.line; g.lineWidth = 1.5; g.stroke();
    }
    function bar(g, x, y, w, h, v, color = C.ok) {
        rr(g, x, y, w, h, h / 2); g.fillStyle = C.dark; g.fill();
        if (v > 0) { rr(g, x, y, Math.max(h, w * clamp(v, 0, 1)), h, h / 2); g.fillStyle = color; g.fill(); }
    }
    const L_KEYS = ['q', 'a', 'arrowleft'], R_KEYS = ['d', 'arrowright'];

    // =================================================================
    //  PORTIÈRE
    // =================================================================
    function doorGame(ctx) {
        const { tol, sp, L } = tune(ctx.params); const R = ctx.rng;
        const panel = { x: 70, y: 50, w: 360, h: 320 };
        // --- 1. Vis : frapper quand l'aiguille traverse le secteur vert
        const screwsN = count(8, L, 3);
        const screws = [];
        for (let i = 0; i < screwsN; i++) {
            const t = i / screwsN; const per = 2 * (panel.w + panel.h); let d = t * per + 30;
            let x, y;
            if (d < panel.w) { x = panel.x + d; y = panel.y + 18; } else if ((d -= panel.w) < panel.h) { x = panel.x + panel.w - 18; y = panel.y + d; }
            else if ((d -= panel.h) < panel.w) { x = panel.x + panel.w - d; y = panel.y + panel.h - 18; } else { d -= panel.w; x = panel.x + 18; y = panel.y + panel.h - d; }
            screws.push({ x: clamp(x, panel.x + 18, panel.x + panel.w - 18), y: clamp(y, panel.y + 18, panel.y + panel.h - 18), out: 0 });
        }
        const p1 = {
            title: 'Vis du panneau', hint: 'Appuyez sur ESPACE (ou clic) quand l\'aiguille traverse la zone verte. 4 quarts de tour par vis.',
            S: { idx: 0, hits: 0, ang: 0, sc: R.range(0, TAU), sw: (50 * tol) * Math.PI / 180, cd: 0, omega: TAU / 1.7 * sp, n: screwsN },
            progress() { return (this.S.idx * 4 + this.S.hits) / (screwsN * 4); },
            update(dt) { const S = this.S; S.ang = (S.ang + S.omega * dt) % TAU; S.cd = Math.max(0, S.cd - dt); },
            act() {
                const S = this.S; if (S.cd > 0 || S.idx >= screwsN) return;
                if (Math.abs(angDiff(S.ang, S.sc)) <= S.sw / 2) {
                    S.hits++; S.cd = 0.35; screws[S.idx].out = S.hits / 4; S.sc = (S.ang + R.range(1.6, 4.7)) % TAU;
                    if (S.hits >= 4) { S.idx++; S.hits = 0; if (S.idx >= screwsN) ctx.done(); }
                } else { S.cd = 0.25; ctx.error('Le tournevis ripe sur la vis.'); }
            },
            down() { this.act(); }, key(k, d) { if (d && k === ' ') this.act(); },
            draw(g) {
                const S = this.S; bg(g);
                drawDoorPanel(g, panel, 0);
                screws.forEach((s, i) => { if (s.out >= 1) { circle(g, s.x, s.y, 6, C.dark); return; } screwHead(g, s.x, s.y, i === S.idx ? 11 : 9, s.out * TAU, 'cross'); if (i === S.idx) circle(g, s.x, s.y, 16, null, C.violet, 2); });
                // gros plan
                const cx = 590, cy = 210, r = 120;
                circle(g, cx, cy, r + 12, C.panel2, C.line);
                g.beginPath(); g.moveTo(cx, cy); g.arc(cx, cy, r, S.sc - S.sw / 2, S.sc + S.sw / 2); g.closePath(); g.fillStyle = 'rgba(61,220,151,.45)'; g.fill();
                screwHead(g, cx, cy, 48, (screws[S.idx] ? screws[S.idx].out : 0) * TAU + S.hits * 0.6, 'cross');
                g.save(); g.translate(cx, cy); g.rotate(S.ang); g.strokeStyle = S.cd > 0 ? C.warn : C.violet2; g.lineWidth = 5; g.lineCap = 'round'; g.beginPath(); g.moveTo(54, 0); g.lineTo(r - 4, 0); g.stroke(); g.restore();
                for (let i = 0; i < 4; i++) circle(g, cx - 36 + i * 24, cy + r + 30, 7, i < S.hits ? C.ok : C.dark, C.line, 1);
                txt(g, `Vis ${Math.min(S.idx + 1, screwsN)} / ${screwsN}`, cx, cy - r - 26, { align: 'center', color: C.mute, size: 13 });
            },
        };
        // --- 2. Clips : maintenir pour forcer, relâcher dans la fenêtre (trop fort = clip cassé)
        const clipsN = count(8, L, 3);
        const clips = [];
        for (let i = 0; i < clipsN; i++) { const t = (i + 0.5) / clipsN; clips.push({ x: panel.x + (i % 2 ? panel.w - 4 : 4), y: panel.y + 30 + t * (panel.h - 60), off: false }); }
        const newWin = () => { const w = 0.14 * tol; const a = R.range(0.42, 0.84 - w); return [a, a + w]; };
        const p2 = {
            title: 'Clips du panneau', hint: 'Maintenez le clic (ou ESPACE) pour faire levier, relâchez dans la zone verte. Trop de force casse le clip.',
            S: { idx: 0, f: 0, hold: false, win: newWin(), cd: 0, wob: R.range(0, 6) },
            progress() { return this.S.idx / clipsN; },
            update(dt, t) {
                const S = this.S; S.cd = Math.max(0, S.cd - dt);
                if (S.hold && S.cd === 0) {
                    S.f += dt * (0.5 * sp) * (0.75 + 0.5 * (0.5 + 0.5 * Math.sin(t * 7 + S.wob)));
                    if (S.f > S.win[1]) { ctx.error('Clip cassé : trop de force.'); this.pop(); }
                }
            },
            pop() { const S = this.S; clips[S.idx].off = true; S.idx++; S.f = 0; S.hold = false; S.cd = 0.5; S.win = newWin(); S.wob = R.range(0, 6); if (S.idx >= clipsN) ctx.done(); },
            press() { if (this.S.cd === 0) this.S.hold = true; },
            release() {
                const S = this.S; if (!S.hold) return; S.hold = false;
                if (S.f >= S.win[0] && S.f <= S.win[1]) this.pop(); else if (S.f > 0.02) { ctx.toast('Le clip résiste…'); S.f = 0; }
            },
            down() { this.press(); }, up() { this.release(); }, key(k, d) { if (k === ' ') d ? this.press() : this.release(); },
            draw(g) {
                const S = this.S; bg(g);
                drawDoorPanel(g, panel, S.idx / clipsN * 6);
                clips.forEach((c, i) => { rr(g, c.x - 9, c.y - 6, 18, 12, 3); g.fillStyle = c.off ? C.dark : (i === S.idx ? C.violet : '#4b4060'); g.fill(); });
                txt(g, `Clip ${Math.min(S.idx + 1, clipsN)} / ${clipsN}`, 590, 90, { align: 'center', color: C.mute, size: 13 });
                // levier
                g.save(); g.translate(590, 230); g.rotate(-0.15 - S.f * 0.6); rr(g, -12, -110, 24, 150, 8); g.fillStyle = '#8f8a9c'; g.fill(); rr(g, -16, 20, 32, 70, 10); g.fillStyle = '#ffb347'; g.fill(); g.restore();
                txt(g, 'Force', 470, 378, { color: C.mute, size: 12 });
                gauge(g, 520, 368, 200, 20, S.f, [{ a: S.win[0], b: S.win[1], c: 'rgba(61,220,151,.55)' }, { a: S.win[1], b: 1, c: 'rgba(255,77,109,.25)' }]);
            },
        };
        // --- 3. Dépose du panneau : glisser lentement (câble de la vitre) puis débrancher la commande
        const p3 = {
            title: 'Dépose du panneau', hint: 'Maintenez le clic sur le panneau et tirez-le vers la droite, LENTEMENT. Puis gardez le curseur sur la prise et maintenez E.',
            S: { stage: 'pull', x: 0, need: 430, grab: false, lastX: 0, speed: 0, over: 0, vmax: 150 / sp, plug: 0, px: 600, py: 210, mx: 0, my: 0, eDown: false },
            progress() { const S = this.S; return S.stage === 'pull' ? (S.x / S.need) * 0.6 : 0.6 + S.plug * 0.4; },
            update(dt, t) {
                const S = this.S;
                if (S.stage === 'pull') {
                    S.speed = lerp(S.speed, S.instant || 0, clamp(dt * 10, 0, 1)); S.instant = 0;
                    if (S.grab && S.speed > S.vmax) { S.over += dt; if (S.over > 0.2) { ctx.error('Le câble de la vitre accroche !'); S.x = Math.max(0, S.x - 110); S.grab = false; S.over = 0; S.speed = 0; } } else S.over = 0;
                    if (S.x >= S.need) { S.stage = 'plug'; ctx.toast('Panneau déposé : débranchez la commande de vitre.'); }
                } else {
                    S.px = 600 + Math.sin(t * 1.1) * 60 * sp; S.py = 210 + Math.cos(t * 1.5) * 45 * sp;
                    const on = dist(S.mx, S.my, S.px, S.py) <= 26 * tol;
                    if (S.eDown && on) S.plug += dt / 4; else S.plug = Math.max(0, S.plug - dt * 0.4);
                    if (S.plug >= 1) ctx.done();
                }
            },
            down(x, y) { const S = this.S; if (S.stage === 'pull' && x >= panel.x + S.x && x <= panel.x + S.x + panel.w && y >= panel.y && y <= panel.y + panel.h) { S.grab = true; S.lastX = x; } },
            up() { this.S.grab = false; },
            move(x, y, dx, dy, dt) {
                const S = this.S; S.mx = x; S.my = y;
                if (S.stage === 'pull' && S.grab) { const d = x - S.lastX; S.lastX = x; S.x = clamp(S.x + d, 0, S.need); if (dt > 0) S.instant = Math.max(S.instant || 0, Math.abs(d) / dt); }
            },
            key(k, d) { if (k === 'e') this.S.eDown = d; },
            draw(g) {
                const S = this.S; bg(g);
                // structure de porte (fond) + cachette révélée
                rr(g, panel.x, panel.y, panel.w, panel.h, 18); g.fillStyle = '#0e0a16'; g.fill();
                rr(g, panel.x + 80, panel.y + 110, 200, 120, 10); g.fillStyle = '#1c1428'; g.fill(); g.strokeStyle = C.line; g.stroke();
                txt(g, 'caisson', panel.x + 180, panel.y + 170, { align: 'center', color: '#4b4060', size: 12 });
                if (S.stage === 'pull') {
                    g.save(); g.globalAlpha = 0.97; drawDoorPanel(g, { ...panel, x: panel.x + S.x }, 6); g.restore();
                    g.strokeStyle = S.over > 0 ? C.bad : '#666'; g.lineWidth = 2; g.beginPath(); g.moveTo(panel.x + 200, panel.y + 200); g.quadraticCurveTo(panel.x + 200 + S.x / 2, panel.y + 260, panel.x + S.x + 200, panel.y + 200); g.stroke();
                    txt(g, 'Vitesse', 470, 378, { color: C.mute, size: 12 });
                    gauge(g, 530, 368, 190, 20, clamp(S.speed / (S.vmax * 1.6), 0, 1), [{ a: 0, b: 1 / 1.6, c: 'rgba(61,220,151,.35)' }, { a: 1 / 1.6, b: 1, c: 'rgba(255,77,109,.35)' }]);
                } else {
                    g.strokeStyle = '#555'; g.lineWidth = 3; g.beginPath(); g.moveTo(panel.x + 200, panel.y + 200); g.lineTo(S.px, S.py); g.stroke();
                    rr(g, S.px - 22, S.py - 14, 44, 28, 6); g.fillStyle = S.plug > 0 ? C.ok : C.warn; g.fill();
                    circle(g, S.px, S.py, 26 * tol, null, 'rgba(201,166,255,.5)', 1.5);
                    txt(g, 'Prise de la commande de vitre', 600, 70, { align: 'center', color: C.mute, size: 13 });
                    bar(g, 500, 372, 200, 12, S.plug);
                }
            },
        };
        return [p1, p2, p3];
    }
    function drawDoorPanel(g, p, ripped) {
        const gr = g.createLinearGradient(p.x, p.y, p.x + p.w, p.y + p.h); gr.addColorStop(0, '#3b2f52'); gr.addColorStop(1, '#241b36');
        rr(g, p.x, p.y, p.w, p.h, 18); g.fillStyle = gr; g.fill(); g.strokeStyle = C.line; g.lineWidth = 2; g.stroke();
        rr(g, p.x + 40, p.y + 40, p.w - 80, 70, 12); g.fillStyle = 'rgba(0,0,0,.25)'; g.fill();          // accoudoir
        rr(g, p.x + p.w - 120, p.y + 60, 60, 24, 8); g.fillStyle = '#6d6680'; g.fill();                     // poignée
        circle(g, p.x + 90, p.y + p.h - 80, 42, '#1a1326', C.line);                                       // haut-parleur
        for (let i = 0; i < ripped; i++) { g.strokeStyle = 'rgba(255,179,71,.35)'; g.beginPath(); g.moveTo(p.x + 10 + i * 8, p.y + p.h - 8); g.lineTo(p.x + 30 + i * 8, p.y + p.h - 30); g.stroke(); }
    }

    // =================================================================
    //  COFFRE
    // =================================================================
    function trunkGame(ctx) {
        const { tol, sp, L } = tune(ctx.params); const R = ctx.rng;
        // --- 1. Rivets : mémoriser l'ordre de démontage puis cliquer dans le même ordre
        const rivets = [];
        for (let r = 0; r < 3; r++) for (let c = 0; c < 4; c++) rivets.push({ x: 130 + c * 165, y: 110 + r * 100 });
        const rounds = [4, 5, 6, 7].map((n) => Math.max(3, Math.round(n * L))).slice(0, L < 0.8 ? 3 : 4);
        const makeSeq = (n) => { const s = []; while (s.length < n) { const i = R.int(0, rivets.length - 1); if (s[s.length - 1] !== i) s.push(i); } return s; };
        const p1 = {
            title: 'Rivets de la garniture', hint: 'Mémorisez l\'ordre des rivets qui s\'allument, puis cliquez-les dans le même ordre.',
            S: { round: 0, seq: makeSeq(rounds[0]), show: 0, showTotal: 0, pos: 0, step: 0.9 / sp, flash: -1, done: [] },
            init() { this.replay(); },
            replay() { const S = this.S; S.showTotal = 0.7 + S.seq.length * S.step; S.show = S.showTotal; S.flash = -1; },
            progress() { return (this.S.round + (this.S.show > 0 ? 0 : this.S.pos / this.S.seq.length)) / rounds.length; },
            update(dt) {
                const S = this.S; if (S.show <= 0) return;
                S.show -= dt; const e = S.showTotal - S.show - 0.7;
                const k = Math.floor(e / S.step);
                S.flash = (e >= 0 && k < S.seq.length && (e % S.step) < S.step * 0.75) ? S.seq[k] : -1;
                if (S.show <= 0) { S.show = 0; S.flash = -1; }
            },
            down(x, y) {
                const S = this.S; if (S.show > 0) return;
                const i = rivets.findIndex((r) => dist(x, y, r.x, r.y) <= 28); if (i < 0) return;
                if (i === S.seq[S.pos]) {
                    S.done.push(i); S.pos++;
                    if (S.pos >= S.seq.length) {
                        S.round++; S.pos = 0; S.done = [];
                        if (S.round >= rounds.length) return ctx.done();
                        S.seq = makeSeq(rounds[S.round]); this.replay();
                    }
                } else { ctx.error('Mauvais rivet : la garniture se tord.'); S.pos = 0; S.done = []; this.replay(); }
            },
            draw(g) {
                const S = this.S; bg(g, '#1a1426', '#0d0a14');
                rr(g, 50, 50, 660, 320, 16); g.fillStyle = '#2b2238'; g.fill(); g.strokeStyle = C.line; g.stroke();
                rivets.forEach((r, i) => {
                    const lit = S.flash === i, done = S.done.includes(i);
                    circle(g, r.x, r.y, 22, lit ? C.violet2 : (done ? C.dark : '#4a4058'), lit ? '#fff' : C.line, lit ? 3 : 1.5);
                    if (!done) circle(g, r.x, r.y, 7, lit ? '#fff' : '#2a2533');
                });
                txt(g, S.show > 0 ? 'Observez…' : `À vous : ${S.pos} / ${S.seq.length}`, W / 2, 390, { align: 'center', color: S.show > 0 ? C.warn : C.ok });
                txt(g, `Série ${Math.min(S.round + 1, rounds.length)} / ${rounds.length}`, 60, 30, { color: C.mute, size: 13 });
            },
        };
        // --- 2. Vis à embouts : choisir le bon embout (1-4), puis maintenir le clic sur la vis qui bouge
        const KINDS = ['torx', 'hex', 'cross', 'flat'], KIND_L = ['Torx', '6 pans', 'Cruciforme', 'Plat'];
        const boltsN = count(5, L, 3);
        const bolts = []; for (let i = 0; i < boltsN; i++) bolts.push({ kind: R.int(0, 3), bx: 160 + (i % 3) * 200, by: i < 3 ? 150 : 270 });
        const p2 = {
            title: 'Vis de fixation', hint: 'Choisissez l\'embout qui correspond à la tête (touches 1 à 4 ou clic), puis maintenez le clic sur la vis sans la perdre.',
            S: { idx: 0, stage: 'bit', bit: -1, p: 0, hold: false, mx: 0, my: 0, vx: 0, vy: 0, r: 40, t: 0, bolts },
            progress() { return (this.S.idx + this.S.p) / boltsN; },
            pos(t) { const b = bolts[this.S.idx]; return [b.bx + Math.sin(t * 1.3 * sp) * 20, b.by + Math.cos(t * 1.7 * sp) * 14]; },
            update(dt, t) {
                const S = this.S; if (S.idx >= boltsN) return; S.t = t;
                const [vx, vy] = this.pos(t); S.vx = vx; S.vy = vy; S.r = lerp(40, 16 * tol, S.p);
                if (S.stage === 'turn' && S.hold) {
                    if (dist(S.mx, S.my, vx, vy) <= S.r) { S.p += dt / (3.6 / sp); if (S.p >= 1) { S.idx++; S.p = 0; S.stage = 'bit'; S.bit = -1; S.hold = false; if (S.idx >= boltsN) ctx.done(); } }
                    else { ctx.error('L\'embout glisse et abîme la tête.'); S.p *= 0.5; S.hold = false; }
                }
            },
            choose(i) {
                const S = this.S; if (S.stage !== 'bit' || S.idx >= boltsN) return;
                if (i === bolts[S.idx].kind) { S.bit = i; S.stage = 'turn'; } else ctx.error('Mauvais embout : la tête s\'abîme.');
            },
            down(x, y) {
                const S = this.S; S.mx = x; S.my = y;
                for (let i = 0; i < 4; i++) if (x >= 170 + i * 110 && x <= 260 + i * 110 && y >= 350 && y <= 400) return this.choose(i);
                if (S.stage === 'turn' && dist(x, y, S.vx, S.vy) <= S.r) S.hold = true;
            },
            up() { this.S.hold = false; }, move(x, y) { this.S.mx = x; this.S.my = y; },
            key(k, d) { if (d && k >= '1' && k <= '4') this.choose(Number(k) - 1); },
            draw(g) {
                const S = this.S; bg(g, '#1a1426', '#0d0a14');
                rr(g, 50, 50, 660, 280, 16); g.fillStyle = '#2b2238'; g.fill();
                bolts.forEach((b, i) => { if (i < S.idx) { circle(g, b.bx, b.by, 8, C.dark); return; } if (i !== S.idx) screwHead(g, b.bx, b.by, 14, 0, KINDS[b.kind]); });
                if (S.idx < boltsN) {
                    screwHead(g, S.vx, S.vy, 24, S.p * TAU * 3, KINDS[bolts[S.idx].kind]);
                    circle(g, S.vx, S.vy, S.r, null, S.stage === 'turn' ? (S.hold ? C.ok : C.violet2) : '#4b4060', 2);
                    if (S.stage === 'turn') bar(g, S.vx - 40, S.vy + S.r + 10, 80, 8, S.p);
                }
                for (let i = 0; i < 4; i++) {
                    rr(g, 170 + i * 110, 350, 90, 50, 10); g.fillStyle = S.bit === i ? C.violet : C.panel2; g.fill(); g.strokeStyle = C.line; g.stroke();
                    screwHead(g, 195 + i * 110, 375, 12, 0, KINDS[i]); txt(g, `${i + 1}`, 240 + i * 110, 366, { size: 12, color: C.mute }); txt(g, KIND_L[i], 240 + i * 110, 386, { size: 10, color: C.mute, align: 'center' });
                }
                txt(g, `Vis ${Math.min(S.idx + 1, boltsN)} / ${boltsN} · ${S.stage === 'bit' ? 'choisissez l\'embout' : 'maintenez le clic sur la vis'}`, 60, 30, { color: C.mute, size: 13 });
            },
        };
        // --- 3. Loquets du double fond : trouver le cran (lueur), puis maintenir ESPACE
        const latchN = count(3, L, 2);
        const targets = []; for (let i = 0; i < latchN; i++) targets.push(R.range(25, 155));
        const p3 = {
            title: 'Loquets du double fond', hint: 'Déplacez la souris de gauche à droite pour tourner le loquet. Quand il s\'illumine au maximum, maintenez ESPACE.',
            S: { idx: 0, a: 90, hold: false, h: 0, win: 6 * tol, target: targets[0] },
            progress() { return (this.S.idx + this.S.h) / latchN; },
            near() { return Math.abs(this.S.a - this.S.target) <= this.S.win; },
            update(dt) {
                const S = this.S; if (S.idx >= latchN) return;
                if (S.hold) {
                    if (!this.near()) { S.hold = false; S.h = 0; ctx.toast('Vous avez perdu le cran.'); }
                    else { S.h += dt / (2.0 / sp); if (S.h >= 1) { S.idx++; S.h = 0; S.hold = false; S.target = targets[S.idx]; if (S.idx >= latchN) ctx.done(); } }
                }
            },
            move(x) { this.S.a = clamp((x - 80) / 600 * 180, 0, 180); },
            key(k, d) {
                const S = this.S; if (k !== ' ') return;
                if (d && !S.hold) { if (this.near()) S.hold = true; else ctx.error('Le loquet force : mauvais cran.'); }
                if (!d) { S.hold = false; S.h = 0; }
            },
            draw(g) {
                const S = this.S; bg(g, '#1a1426', '#0d0a14');
                const glow = clamp(1 - Math.abs(S.a - (S.target || 0)) / 35, 0, 1);
                rr(g, 120, 70, 520, 250, 16); g.fillStyle = '#251d31'; g.fill();
                const cx = 380, cy = 210;
                circle(g, cx, cy, 110, `rgba(155,92,255,${0.08 + glow * glow * 0.55})`, C.line);
                g.save(); g.translate(cx, cy); g.rotate((S.a - 90) * Math.PI / 180); rr(g, -14, -100, 28, 120, 10); g.fillStyle = S.hold ? C.ok : '#a7a1b6'; g.fill(); circle(g, 0, 0, 18, '#2a2533'); g.restore();
                for (let i = 0; i < latchN; i++) circle(g, 340 + i * 30, 360, 8, i < S.idx ? C.ok : C.dark, C.line, 1);
                if (S.hold) bar(g, 300, 385, 160, 10, S.h);
                txt(g, `Loquet ${Math.min(S.idx + 1, latchN)} / ${latchN}`, 60, 30, { color: C.mute, size: 13 });
            },
        };
        return [p1, p2, p3];
    }

    // =================================================================
    //  PASSAGE DE ROUE
    // =================================================================
    function wheelGame(ctx) {
        const { tol, sp, L } = tune(ctx.params); const R = ctx.rng;
        // --- 1. Écrous rouillés : garder l'aiguille de couple dans la zone en bougeant la souris (haut / bas)
        const nutsN = count(7, L, 3);
        const ph = [R.range(0, 6), R.range(0, 6), R.range(0, 6)];
        const p1 = {
            title: 'Écrous de l\'aile', hint: 'Maintenez le clic pour serrer la clé, et gardez l\'aiguille dans la zone verte en bougeant la souris vers le haut ou le bas.',
            S: { idx: 0, v: 0.5, p: 0, hold: false, out: 0, band: 0.085 * tol },
            progress() { return (this.S.idx + this.S.p) / nutsN; },
            inBand() { return Math.abs(this.S.v - 0.5) <= this.S.band; },
            update(dt, t) {
                const S = this.S; if (S.idx >= nutsN || !S.hold) return;
                const n = Math.sin(t * 1.7 + ph[0]) * 0.6 + Math.sin(t * 3.1 + ph[1]) * 0.3 + Math.sin(t * 5.3 + ph[2]) * 0.25;
                S.v = clamp(S.v + n * 0.42 * sp * dt, 0, 1);
                if (this.inBand()) { S.out = 0; S.p += dt / 3.8; if (S.p >= 1) { S.idx++; S.p = 0; S.hold = false; S.v = 0.5; if (S.idx >= nutsN) ctx.done(); } }
                else { S.out += dt; if (S.out > 1.0) { ctx.error('Tête d\'écrou abîmée.'); S.out = 0; S.p = Math.max(0, S.p - 0.3); } }
            },
            down() { this.S.hold = true; }, up() { this.S.hold = false; this.S.out = 0; },
            move(x, y, dx, dy) { const S = this.S; if (S.hold) S.v = clamp(S.v - dy / 260, 0, 1); },
            draw(g) {
                const S = this.S; bg(g, '#14101c', '#08060c');
                // aile et écrous
                g.beginPath(); g.arc(230, 330, 200, Math.PI, TAU); g.lineWidth = 34; g.strokeStyle = '#2d2438'; g.stroke();
                for (let i = 0; i < nutsN; i++) { const a = Math.PI + (i + 0.5) / nutsN * Math.PI; const x = 230 + Math.cos(a) * 200, y = 330 + Math.sin(a) * 200; if (i < S.idx) circle(g, x, y, 6, C.dark); else { circle(g, x, y, i === S.idx ? 13 : 10, '#8a5a3c', i === S.idx ? C.violet : '#3a2a20', 2); } }
                circle(g, 230, 330, 140, '#0f0c14', '#222', 2);
                // couple
                const x0 = 560, y0 = 60, h = 300;
                rr(g, x0, y0, 50, h, 12); g.fillStyle = C.dark; g.fill();
                g.fillStyle = 'rgba(61,220,151,.45)'; g.fillRect(x0 + 3, y0 + h * (0.5 - S.band), 44, h * S.band * 2);
                g.fillStyle = S.hold ? (this.inBand() ? C.ok : C.bad) : C.violet2; g.fillRect(x0 - 8, y0 + h * (1 - S.v) - 3, 66, 6);
                txt(g, 'Couple', x0 + 25, y0 - 16, { align: 'center', color: C.mute, size: 12 });
                bar(g, 640, 200, 90, 10, S.p);
                txt(g, `Écrou ${Math.min(S.idx + 1, nutsN)} / ${nutsN}`, 685, 180, { align: 'center', color: C.mute, size: 13 });
            },
        };
        // --- 2. Agrafes cachées : chercher avec la lampe, cliquer exactement dessus
        const clipsN = count(9, L, 3);
        const hidden = []; while (hidden.length < clipsN) { const a = R.range(Math.PI * 1.05, Math.PI * 1.95); const r = R.range(120, 230); const x = 380 + Math.cos(a) * r * 1.4, y = 380 + Math.sin(a) * r; if (hidden.every((h) => dist(h.x, h.y, x, y) > 60)) hidden.push({ x, y, off: false }); }
        const p2 = {
            title: 'Agrafes du pare-boue', hint: 'Les agrafes sont dans l\'ombre : balayez avec la lampe (souris) et cliquez précisément sur chaque agrafe.',
            S: { mx: 380, my: 200, light: 65 * tol, found: 0, hidden, busy: 0 },
            progress() { return this.S.found / clipsN; },
            update(dt) { const S = this.S; if (S.busy > 0) { S.busy -= dt; if (S.busy <= 0 && S.found >= clipsN) ctx.done(); } },
            move(x, y) { this.S.mx = x; this.S.my = y; },
            down(x, y) {
                const S = this.S; if (S.busy > 0) return;
                const c = hidden.find((h) => !h.off && dist(h.x, h.y, x, y) <= 20 && dist(h.x, h.y, S.mx, S.my) <= S.light);
                if (c) { c.off = true; S.found++; S.busy = 0.8; ctx.toast('Dégrafage…'); }
                else ctx.error('Vous rayez la carrosserie.');
            },
            draw(g) {
                const S = this.S; g.fillStyle = '#050407'; g.fillRect(0, 0, W, H);
                g.save(); g.beginPath(); g.arc(S.mx, S.my, S.light, 0, TAU); g.clip();
                const gr = g.createRadialGradient(S.mx, S.my, 5, S.mx, S.my, S.light); gr.addColorStop(0, '#3a3046'); gr.addColorStop(1, '#141018'); g.fillStyle = gr; g.fillRect(0, 0, W, H);
                g.strokeStyle = '#2a2232'; g.lineWidth = 2; for (let i = 0; i < 16; i++) { g.beginPath(); g.arc(380, 380, 110 + i * 9, Math.PI, TAU); g.stroke(); }
                hidden.forEach((h) => { if (!h.off) { rr(g, h.x - 9, h.y - 9, 18, 18, 4); g.fillStyle = '#d7d2e2'; g.fill(); circle(g, h.x, h.y, 4, '#555'); } });
                g.restore();
                circle(g, S.mx, S.my, S.light, null, 'rgba(255,240,200,.25)', 2);
                txt(g, `Agrafes retirées : ${S.found} / ${clipsN}`, 20, 24, { color: C.mute, size: 13 });
            },
        };
        // --- 3. Pare-boue : pomper à la molette (ou ESPACE) et tenir dans la zone sans dépasser
        const p3 = {
            title: 'Dégagement du compartiment', hint: 'Faites tourner la molette (ou tapez ESPACE) pour soulever le pare-boue. Restez dans la zone verte 8 secondes au total, sans dépasser.',
            S: { lv: 0, p: 0, zone: [0.78, 0.78 + 0.16 * tol], cd: 0 },
            progress() { return this.S.p; },
            update(dt) {
                const S = this.S; S.lv = Math.max(0, S.lv - dt * 0.13 * sp); S.cd = Math.max(0, S.cd - dt);
                if (S.lv > 1) { ctx.error('Le pare-boue se fend !'); S.lv = 0.55; }
                if (S.lv >= S.zone[0] && S.lv <= S.zone[1]) { S.p += dt / 8; if (S.p >= 1) ctx.done(); }
            },
            pump() { const S = this.S; if (S.cd > 0) return; S.cd = 0.06; S.lv += 0.042; },
            wheel() { this.pump(); }, key(k, d) { if (d && k === ' ') this.pump(); },
            draw(g) {
                const S = this.S; bg(g, '#14101c', '#08060c');
                g.save(); g.translate(250, 330); g.rotate(-S.lv * 0.6); rr(g, -10, -200, 260, 30, 12); g.fillStyle = '#3c3049'; g.fill(); g.restore();
                rr(g, 120, 260, 220, 120, 12); g.fillStyle = '#1b1524'; g.fill(); g.strokeStyle = C.line; g.stroke();
                if (S.lv > 0.6) { rr(g, 160, 290, 140, 60, 8); g.fillStyle = `rgba(155,92,255,${(S.lv - 0.6) * 1.2})`; g.fill(); }
                const x0 = 560, y0 = 50, h = 320, top = 1.1, Y = (v) => y0 + h * (1 - v / top);
                rr(g, x0, y0, 50, h, 12); g.fillStyle = C.dark; g.fill();
                g.fillStyle = 'rgba(255,77,109,.35)'; g.fillRect(x0 + 3, y0 + 3, 44, Y(1) - y0 - 3);
                g.fillStyle = 'rgba(61,220,151,.45)'; g.fillRect(x0 + 3, Y(S.zone[1]), 44, Y(S.zone[0]) - Y(S.zone[1]));
                g.fillStyle = C.violet2; g.fillRect(x0 - 8, Y(clamp(S.lv, 0, top)) - 3, 66, 6);
                bar(g, 640, 210, 90, 10, S.p);
            },
        };
        return [p1, p2, p3];
    }

    // =================================================================
    //  SIÈGE
    // =================================================================
    function seatGame(ctx) {
        const { tol, sp, L } = tune(ctx.params); const R = ctx.rng;
        // --- 1. Glissières : à-coups en rythme (Q / ← et D / →)
        const notesN = count(26, L, 8);
        const interval = 0.78 / sp, travel = 1.6, win = 0.17 * tol;
        const notes = []; let tt = 2.2; for (let i = 0; i < notesN; i++) { notes.push({ t: tt, lane: R() < 0.5 ? 0 : 1, hit: false, miss: false }); tt += interval * R.range(0.85, 1.2); }
        const p1 = {
            title: 'Glissières du siège', hint: 'Donnez les à-coups en rythme : Q (ou ←) pour la gauche, D (ou →) pour la droite, quand la note touche la ligne.',
            S: { time: 0, notes, done: 0, win },
            progress() { return this.S.done / notesN; },
            update(dt) {
                const S = this.S; S.time += dt;
                for (const n of notes) if (!n.hit && !n.miss && S.time > n.t + win) { n.miss = true; S.done++; ctx.error('À-coup manqué : le rail se bloque.'); }
                if (S.done >= notesN) ctx.done();
            },
            key(k, d) {
                if (!d) return; const lane = L_KEYS.includes(k) ? 0 : (R_KEYS.includes(k) ? 1 : -1); if (lane < 0) return;
                const S = this.S;
                const n = notes.find((x) => !x.hit && !x.miss && x.lane === lane && Math.abs(x.t - S.time) <= win);
                if (n) { n.hit = true; S.done++; if (S.done >= notesN) ctx.done(); return; }
                if (notes.some((x) => !x.hit && !x.miss && Math.abs(x.t - S.time) <= win)) ctx.error('Mauvais côté : le siège se coince.');
            },
            draw(g) {
                const S = this.S; bg(g, '#1b1424', '#0b0810');
                const lx = [300, 460], ly = 340;
                for (let l = 0; l < 2; l++) { rr(g, lx[l] - 50, 30, 100, 360, 14); g.fillStyle = C.panel2; g.fill(); }
                g.fillStyle = C.violet; g.fillRect(230, ly - 2, 300, 4);
                txt(g, 'Q / ←', lx[0], 405, { align: 'center', color: C.mute }); txt(g, 'D / →', lx[1], 405, { align: 'center', color: C.mute });
                for (const n of notes) {
                    if (n.hit) continue; const y = ly - (n.t - S.time) / travel * (ly - 40);
                    if (y < 20 || y > 400) continue; rr(g, lx[n.lane] - 40, y - 12, 80, 24, 10); g.fillStyle = n.miss ? C.bad : C.violet2; g.fill();
                }
                txt(g, `${S.done} / ${notesN}`, 120, 210, { align: 'center', size: 22 });
                // rail
                rr(g, 580, 120, 140, 30, 8); g.fillStyle = '#3c3049'; g.fill(); rr(g, 580 + (S.done / notesN) * 100, 100, 40, 70, 8); g.fillStyle = '#6a5c80'; g.fill();
            },
        };
        // --- 2. Agrafes du revêtement : pince en deux temps (saisir, puis tirer)
        const stapN = count(14, L, 5);
        const life = 2.0 * tol / sp;
        const p2 = {
            title: 'Agrafes du revêtement', hint: 'Une agrafe apparaît : cliquez une fois pour la saisir à la pince, puis une seconde fois pour l\'arracher. Ne la laissez pas filer.',
            S: { pulled: 0, live: [], next: 0.6, spawned: 0, life },
            progress() { return this.S.pulled / stapN; },
            update(dt) {
                const S = this.S; S.next -= dt;
                if (S.next <= 0 && S.spawned < stapN && S.live.length < 2) { S.live.push({ x: R.range(140, 620), y: R.range(80, 340), age: 0, grip: -1 }); S.spawned++; S.next = R.range(0.4, 0.9) / sp; }
                for (const s of S.live) s.age += dt;
                const lost = S.live.filter((s) => s.age > S.life);
                if (lost.length) { S.live = S.live.filter((s) => s.age <= S.life); lost.forEach(() => { ctx.error('Une agrafe vous échappe.'); S.pulled++; }); }
                if (S.pulled >= stapN) ctx.done();
            },
            down(x, y) {
                const S = this.S; const s = S.live.find((o) => dist(o.x, o.y, x, y) <= 24); if (!s) return;
                if (s.grip < 0) s.grip = s.age; else if (s.age - s.grip >= 0.25) { S.live = S.live.filter((o) => o !== s); S.pulled++; if (S.pulled >= stapN) ctx.done(); }
            },
            draw(g) {
                const S = this.S; bg(g, '#1b1424', '#0b0810');
                rr(g, 100, 50, 560, 320, 40); g.fillStyle = '#3a2c48'; g.fill(); for (let i = 0; i < 6; i++) { g.strokeStyle = '#2c2138'; g.lineWidth = 3; g.beginPath(); g.moveTo(130, 90 + i * 50); g.lineTo(630, 90 + i * 50); g.stroke(); }
                for (const s of S.live) {
                    const k = 1 - s.age / S.life;
                    circle(g, s.x, s.y, 24, null, `rgba(201,166,255,${0.25 + 0.6 * k})`, 2);
                    g.strokeStyle = s.grip >= 0 ? C.warn : '#e8e4ef'; g.lineWidth = 4; g.beginPath(); g.moveTo(s.x - 10, s.y + 6); g.lineTo(s.x - 10, s.y - 6); g.lineTo(s.x + 10, s.y - 6); g.lineTo(s.x + 10, s.y + 6); g.stroke();
                    g.beginPath(); g.arc(s.x, s.y, 28, -Math.PI / 2, -Math.PI / 2 + TAU * k); g.strokeStyle = k < 0.3 ? C.bad : C.ok; g.lineWidth = 3; g.stroke();
                }
                txt(g, `Agrafes : ${S.pulled} / ${stapN}`, 20, 24, { color: C.mute, size: 13 });
            },
        };
        // --- 3. Couture : suivre le fil en maintenant le clic, sans sortir ni aller trop vite
        const pts = []; const rows = L < 0.8 ? 2 : 3;
        for (let r = 0; r < rows; r++) {
            const y0 = 90 + r * (260 / Math.max(1, rows - 1)); const dir = r % 2 ? -1 : 1; const ph = R.range(0, 6);
            for (let i = 0; i <= 40; i++) { const u = i / 40; const x = dir > 0 ? 90 + u * 580 : 670 - u * 580; pts.push([x, y0 + Math.sin(u * 7 + ph) * 18]); }
        }
        const cum = [0]; for (let i = 1; i < pts.length; i++) cum.push(cum[i - 1] + dist(pts[i][0], pts[i][1], pts[i - 1][0], pts[i - 1][1]));
        const total = cum[cum.length - 1];
        const at = (s) => { let i = 1; while (i < cum.length - 1 && cum[i] < s) i++; const u = (s - cum[i - 1]) / Math.max(1e-6, cum[i] - cum[i - 1]); return [lerp(pts[i - 1][0], pts[i][0], u), lerp(pts[i - 1][1], pts[i][1], u)]; };
        const p3 = {
            title: 'Couture du revêtement', hint: 'Posez le cutter au début du fil (point violet), maintenez le clic et suivez la couture. Trop vite, le tissu se déchire.',
            S: { s: 0, hold: false, tube: 18 * tol, vmax: 150 * sp, fast: 0, speed: 0, total, mx: 0, my: 0 },
            at,
            progress() { return this.S.s / total; },
            update(dt) {
                const S = this.S; if (!S.hold) { S.speed = 0; return; }
                const [px, py] = at(S.s);
                if (dist(S.mx, S.my, px, py) > S.tube * 2.2) { ctx.error('Vous sortez de la couture.'); S.hold = false; S.s = Math.max(0, S.s - 60); return; }
                // avance : on cherche le point du fil le plus proche du curseur, un peu en avant seulement
                let best = S.s, bd = 1e9; for (let s = S.s; s <= Math.min(total, S.s + 50); s += 2) { const [x, y] = at(s); const d = dist(x, y, S.mx, S.my); if (d < bd) { bd = d; best = s; } }
                if (bd <= S.tube) { const ds = best - S.s; S.speed = lerp(S.speed, ds / Math.max(dt, 1e-3), clamp(dt * 8, 0, 1)); S.s = best; }
                if (S.speed > S.vmax) { S.fast += dt; if (S.fast > 0.2) { ctx.error('Le tissu se déchire : trop vite.'); S.hold = false; S.s = Math.max(0, S.s - 60); S.fast = 0; S.speed = 0; } } else S.fast = 0;
                if (S.s >= total - 2) ctx.done();
            },
            down(x, y) { const S = this.S; S.mx = x; S.my = y; const [px, py] = at(S.s); if (dist(x, y, px, py) <= S.tube * 1.6) S.hold = true; },
            up() { this.S.hold = false; }, move(x, y) { this.S.mx = x; this.S.my = y; },
            draw(g) {
                const S = this.S; bg(g, '#1b1424', '#0b0810');
                rr(g, 60, 50, 640, 340, 30); g.fillStyle = '#3a2c48'; g.fill();
                g.lineWidth = S.tube * 2; g.strokeStyle = 'rgba(255,255,255,.04)'; g.beginPath(); pts.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.stroke();
                g.setLineDash([6, 6]); g.lineWidth = 2; g.strokeStyle = '#d9cdee'; g.stroke(); g.setLineDash([]);
                g.lineWidth = 6; g.strokeStyle = '#120c18'; g.beginPath(); for (let s = 0; s <= S.s; s += 4) { const [x, y] = at(s); s ? g.lineTo(x, y) : g.moveTo(x, y); } g.stroke();
                const [px, py] = at(S.s); circle(g, px, py, 9, C.violet, '#fff', 2);
                txt(g, 'Vitesse', 470, 404, { color: C.mute, size: 12 });
                gauge(g, 530, 396, 190, 14, clamp(S.speed / (S.vmax * 1.5), 0, 1), [{ a: 0, b: 1 / 1.5, c: 'rgba(61,220,151,.35)' }, { a: 1 / 1.5, b: 1, c: 'rgba(255,77,109,.35)' }]);
            },
        };
        return [p1, p2, p3];
    }

    // =================================================================
    //  SOUS LA SELLE (motos, scooters)
    // =================================================================
    function saddleGame(ctx) {
        const { tol, sp, L } = tune(ctx.params); const R = ctx.rng;
        // --- 1. Serrure : chaque goupille a sa hauteur ; elle vibre quand on s'en approche → ESPACE pour la caler
        const pinsN = count(7, L, 3);
        const tg = []; for (let i = 0; i < pinsN; i++) tg.push(R.range(0.15, 0.9));
        const p1 = {
            title: 'Serrure de la selle', hint: 'Montez ou descendez la souris pour soulever la goupille. Quand elle vibre fort, tenez-la immobile puis appuyez sur ESPACE (ou clic). Une erreur fait retomber toutes les goupilles.',
            S: { idx: 0, h: 0, win: 0.04 * tol, tg, t: 0, steady: 0 },
            progress() { return this.S.idx / pinsN; },
            shake() { return clamp(1 - Math.abs(this.S.h - tg[this.S.idx]) / 0.22, 0, 1); },
            update(dt, t) { const S = this.S; S.t = t; if (S.idx < pinsN && Math.abs(S.h - tg[S.idx]) <= S.win) S.steady += dt; else S.steady = 0; },
            move(x, y) { this.S.h = clamp(1 - (y - 70) / 280, 0, 1); },
            set() {
                const S = this.S; if (S.idx >= pinsN) return;
                if (Math.abs(S.h - tg[S.idx]) <= S.win) { if (S.steady < 0.6) { ctx.toast('Pas encore calée : tenez la goupille immobile.'); return; } S.idx++; S.steady = 0; if (S.idx >= pinsN) ctx.done(); }
                else { ctx.error('Les goupilles retombent.'); S.idx = 0; }
            },
            down() { this.set(); }, key(k, d) { if (d && k === ' ') this.set(); },
            draw(g) {
                const S = this.S; bg(g, '#18121f', '#08060c');
                rr(g, 130, 80, 500, 260, 20); g.fillStyle = '#2b2236'; g.fill(); g.strokeStyle = C.line; g.stroke();
                for (let i = 0; i < pinsN; i++) {
                    const x = 180 + i * (400 / Math.max(1, pinsN - 1)); let h = i < S.idx ? tg[i] : (i === S.idx ? S.h : 0);
                    let sx = 0; if (i === S.idx) { const k = this.shake(); sx = Math.sin(S.t * 60) * 4 * k * k; }
                    rr(g, x - 14 + sx, 300 - h * 200 - 70, 28, 70, 6); g.fillStyle = i < S.idx ? C.ok : (i === S.idx ? C.violet2 : '#6a5c80'); g.fill();
                    g.strokeStyle = '#120c18'; g.beginPath(); g.moveTo(x - 20, 120); g.lineTo(x + 20, 120); g.stroke();
                }
                g.fillStyle = 'rgba(255,255,255,.08)'; g.fillRect(140, 118, 480, 4);
                txt(g, `Goupille ${Math.min(S.idx + 1, pinsN)} / ${pinsN}`, 60, 30, { color: C.mute, size: 13 });
            },
        };
        // --- 2. Coque : dévisser en faisant des cercles dans le sens inverse des aiguilles d'une montre
        const boltsN = count(6, L, 3);
        const p2 = {
            title: 'Boulons de la coque', hint: 'Maintenez le clic et tournez autour du boulon dans le sens INVERSE des aiguilles d\'une montre. 4 tours par boulon, sans forcer trop vite.',
            S: { idx: 0, turn: 0, need: 4 * TAU, hold: false, last: null, speed: 0, vmax: (540 * Math.PI / 180) * 1.25 / sp * tol, cx: 380, cy: 220, slip: 0 },
            progress() { return (this.S.idx + this.S.turn / this.S.need) / boltsN; },
            update(dt) {
                const S = this.S; S.speed = lerp(S.speed, S.inst || 0, clamp(dt * 10, 0, 1)); S.inst = 0;
                if (S.speed > S.vmax) { S.slip += dt; if (S.slip > 0.15) { ctx.error('La clé dérape.'); S.turn = Math.max(0, S.turn - Math.PI / 2); S.slip = 0; S.speed = 0; S.hold = false; S.last = null; } } else S.slip = 0;
            },
            down(x, y) { const S = this.S; S.hold = true; S.last = Math.atan2(y - S.cy, x - S.cx); },
            up() { this.S.hold = false; this.S.last = null; },
            move(x, y, dx, dy, dt) {
                const S = this.S; if (!S.hold || S.idx >= boltsN) return;
                const r = dist(x, y, S.cx, S.cy); const a = Math.atan2(y - S.cy, x - S.cx);
                if (r < 35 || r > 170) { S.last = a; return; }
                if (S.last !== null) {
                    const d = -angDiff(a, S.last);                        // sens inverse des aiguilles = angle écran décroissant
                    S.turn = clamp(S.turn + d, 0, S.need);
                    if (dt > 0) S.inst = Math.max(S.inst || 0, Math.abs(d) / dt);
                    if (S.turn >= S.need) { S.idx++; S.turn = 0; S.hold = false; S.last = null; if (S.idx >= boltsN) ctx.done(); return; }
                }
                S.last = a;
            },
            draw(g) {
                const S = this.S; bg(g, '#18121f', '#08060c');
                for (let i = 0; i < boltsN; i++) circle(g, 120 + i * 40, 380, 10, i < S.idx ? C.ok : C.dark, C.line, 1);
                circle(g, S.cx, S.cy, 170, null, 'rgba(155,92,255,.15)', 1); circle(g, S.cx, S.cy, 35, null, 'rgba(155,92,255,.15)', 1);
                g.save(); g.translate(S.cx, S.cy); g.rotate(-S.turn); for (let i = 0; i < 6; i++) { g.rotate(TAU / 6); rr(g, -8, -60, 16, 30, 4); g.fillStyle = '#5c556a'; g.fill(); } g.restore();
                screwHead(g, S.cx, S.cy, 30, -S.turn, 'hex');
                g.beginPath(); g.arc(S.cx, S.cy, 110, -Math.PI / 2, -Math.PI / 2 - (S.turn / S.need) * TAU, true); g.strokeStyle = C.ok; g.lineWidth = 8; g.stroke();
                txt(g, '↺', S.cx + 140, S.cy - 120, { size: 34, color: C.violet2 });
                gauge(g, 560, 380, 170, 14, clamp(S.speed / (S.vmax * 1.5), 0, 1), [{ a: 0, b: 1 / 1.5, c: 'rgba(61,220,151,.35)' }, { a: 1 / 1.5, b: 1, c: 'rgba(255,77,109,.35)' }]);
                txt(g, `Boulon ${Math.min(S.idx + 1, boltsN)} / ${boltsN}`, 60, 30, { color: C.mute, size: 13 });
            },
        };
        // --- 3. Bac : il monte tout seul, gardez-le à plat avec Q / D (ou ← →)
        const dur = 22 * Math.max(0.7, L) / sp;
        const p3 = {
            title: 'Retrait du bac', hint: 'Le bac remonte tout seul : gardez-le à plat avec Q (ou ←) et D (ou →). S\'il penche trop, il retombe.',
            S: { p: 0, th: 0, om: 0, left: false, right: false, lim: 25 * tol, noise: 0, dur },
            progress() { return this.S.p; },
            update(dt, t) {
                const S = this.S;
                S.noise += (R() - 0.5) * 220 * sp * dt; S.noise *= Math.pow(0.35, dt);
                const torque = S.noise + Math.sin(t * 0.9) * 25 * sp + (S.right ? 70 : 0) - (S.left ? 70 : 0);
                S.om = (S.om + torque * dt) * Math.pow(0.4, dt); S.th += S.om * dt;
                if (Math.abs(S.th) > S.lim) { ctx.error('Le bac bascule.'); S.p = Math.max(0, S.p - 0.25); S.th = 0; S.om = 0; S.noise = 0; }
                S.p += dt / S.dur; if (S.p >= 1) ctx.done();
            },
            key(k, d) { if (L_KEYS.includes(k)) this.S.left = d; if (R_KEYS.includes(k)) this.S.right = d; },
            draw(g) {
                const S = this.S; bg(g, '#18121f', '#08060c');
                rr(g, 170, 330, 420, 40, 12); g.fillStyle = '#2b2236'; g.fill();
                g.save(); g.translate(380, 320 - S.p * 220); g.rotate(S.th * Math.PI / 180); rr(g, -140, -30, 280, 60, 10); g.fillStyle = Math.abs(S.th) > S.lim * 0.7 ? C.bad : '#6a5c80'; g.fill(); txt(g, 'bac', 0, 0, { align: 'center', color: '#2b2236' }); g.restore();
                gauge(g, 560, 40, 170, 16, (S.th + S.lim) / (2 * S.lim), [{ a: 0.3, b: 0.7, c: 'rgba(61,220,151,.35)' }]);
                txt(g, 'Inclinaison', 560, 24, { color: C.mute, size: 12 });
                bar(g, 40, 40, 160, 10, S.p);
            },
        };
        return [p1, p2, p3];
    }

    window.CachGames = { door: doorGame, trunk: trunkGame, wheel: wheelGame, seat: seatGame, saddle: saddleGame, rng, W, H };
})();
