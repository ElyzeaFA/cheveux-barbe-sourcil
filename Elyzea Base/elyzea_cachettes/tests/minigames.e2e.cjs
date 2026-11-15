// =====================================================================
//  Test hors jeu des 5 mini-jeux (Chromium + Playwright) : node tests/minigames.e2e.cjs
//  · un « joueur automatique » parfait termine chaque mini-jeu : toutes les étapes sont réalisables,
//    et on mesure la durée PLANCHER (un humain met plus longtemps) ;
//  · échec par excès d'erreurs, annulation par Échap, choix de l'emplacement ;
//  · captures d'écran dans tests/shots/.
// =====================================================================
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const ROOT = path.join(__dirname, '..');
const URL = 'file://' + path.join(ROOT, 'html', 'index.html');
const SHOTS = path.join(__dirname, 'shots');
fs.mkdirSync(SHOTS, { recursive: true });

let fails = 0, passes = 0;
const check = (c, l) => { if (c) { passes++; console.log('  ok   ' + l); } else { fails++; console.log('  ÉCHEC ' + l); } };

// Joueur automatique : lit l'état de l'étape en cours et agit comme un joueur parfait (un peu de latence)
const BOT = `
window.__bot = { on: true, sloppy: false, last: 0, mem: {} };
(function tick(now) {
  requestAnimationFrame(tick);
  const B = window.__bot; const r = window.__cach.run;
  if (!B.on || !r || r.ended || r.intro > 0 || r.phaseDone) return;
  const p = r.phases[r.idx]; const S = p.S; const key = r.game + r.idx; const dt = Math.min(0.05, (now - (B.last || now)) / 1000); B.last = now;
  const TAU = Math.PI * 2; const ad = (a, b) => { let d = (a - b) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return d; };
  const M = B.mem[key] = B.mem[key] || { t: 0 }; M.t += dt;
  if (B.sloppy) { if (M.t > 0.3) { M.t = 0; p.down && p.down(5, 5); p.key && p.key(' ', true); p.key && p.key(' ', false); } return; }
  switch (key) {
    case 'door0': if (S.cd === 0 && Math.abs(ad(S.ang, S.sc)) < S.sw / 4) { p.key(' ', true); p.key(' ', false); } break;
    case 'door1': if (!S.hold && S.cd === 0) p.key(' ', true); else if (S.hold && S.f >= (S.win[0] + S.win[1]) / 2) p.key(' ', false); break;
    case 'door2':
      if (S.stage === 'pull') { const x = 70 + S.x + 60; if (!S.grab) { p.move(x, 200, 0, 0, dt); p.down(x, 200); } else p.move(x + S.vmax * 0.6 * dt, 200, 0, 0, dt); }
      else { p.move(S.px, S.py, 0, 0, dt); if (!S.eDown) p.key('e', true); }
      break;
    case 'trunk0': if (S.show <= 0 && M.t > 0.25) { M.t = 0; const R = [0,1,2].flatMap(r=>[0,1,2,3].map(c=>[130+c*165,110+r*100])); const i = S.seq[S.pos]; p.down(R[i][0], R[i][1]); } break;
    case 'trunk1': if (S.stage === 'bit') { if (M.t > 0.4) { M.t = 0; p.key(String(S.bolts[S.idx].kind + 1), true); } }
      else { p.move(S.vx, S.vy); if (!S.hold) p.down(S.vx, S.vy); } break;
    case 'trunk2': p.move(80 + S.target / 180 * 600); if (!S.hold && Math.abs(S.a - S.target) <= S.win * 0.5) p.key(' ', true); break;
    case 'wheel0': if (!S.hold) p.down(); else p.move(0, 0, 0, (S.v - 0.5) * 260 * 0.8, dt); break;
    case 'wheel1': if (M.t > 0.35 && !(S.busy > 0)) { M.t = 0; const c = S.hidden.find(h => !h.off); if (c) { p.move(c.x, c.y); p.down(c.x, c.y); } } break;
    case 'wheel2': if (S.lv < (S.zone[0] + S.zone[1]) / 2 - 0.02) p.wheel(1); break;
    case 'seat0': { const n = S.notes.find(n => !n.hit && !n.miss && Math.abs(n.t - S.time) < 0.04); if (n) { const k = n.lane ? 'd' : 'q'; p.key(k, true); p.key(k, false); } break; }
    case 'seat1': for (const s of S.live) { if (s.age > 0.35 && s.grip < 0) p.down(s.x, s.y); else if (s.grip >= 0 && s.age - s.grip >= 0.3) p.down(s.x, s.y); } break;
    case 'seat2': { if (!S.hold) { const [x, y] = p.at(S.s); p.down(x, y); } else { const [x, y] = p.at(Math.min(S.total, S.s + S.vmax * 0.6 * dt)); p.move(x, y); } break; }
    case 'saddle0': p.move(0, 70 + (1 - S.tg[S.idx]) * 280); if (S.steady > 0.65) { p.key(' ', true); p.key(' ', false); } break;
    case 'saddle1': { M.a = (M.a ?? 0) - S.vmax * 0.6 * dt; const x = S.cx + Math.cos(M.a) * 100, y = S.cy + Math.sin(M.a) * 100; if (!S.hold) p.down(x, y); else p.move(x, y, 0, 0, dt); break; }
    case 'saddle2': { const u = S.th + S.om * 0.6; p.key('q', u > 0.5); p.key('d', u < -0.5); break; }
  }
})(performance.now());
`;

async function waitResult(page, timeout) {
    return page.waitForFunction(() => window.__posts.find((p) => p.name === 'result'), null, { timeout, polling: 200 }).then((h) => h.jsonValue());
}

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => { if (m.type() === 'error' && !/Failed to fetch|ERR_|net::/.test(m.text())) errors.push(m.text()); });
    await page.route('https://elyzea_cachettes/**', (r) => r.fulfill({ status: 200, body: '{}' }));

    console.log('\n[Choix de l\'emplacement]');
    await page.goto(URL);
    await page.evaluate(() => window.postMessage({ action: 'slots', role: 'crime', plate: 'ELY 42', category: 'SUV et grands véhicules', slots: [
        { id: 'door_fl', label: 'Portière avant gauche', type: 'door', status: 'free', capacity: 15, game: 'Retrait des vis et déclipsage du panneau' },
        { id: 'trunk', label: 'Coffre (garniture)', type: 'trunk', status: 'installed', capacity: 30 },
        { id: 'wheel_fl', label: 'Passage de roue avant gauche', type: 'wheel', status: 'free', capacity: 15, attempts: 1 },
        { id: 'seat_p', label: 'Siège passager avant', type: 'seat', status: 'free', capacity: 15, disabled: true, desc: 'Siège occupé' },
    ] }, '*'));
    await page.waitForSelector('#picker:not(.hidden)');
    await page.screenshot({ path: path.join(SHOTS, 'picker.png') });
    const labels = await page.$$eval('#pkList .slot b', (b) => b.map((x) => x.textContent));
    check(labels[0].startsWith('Installer') && labels[1].startsWith('Ouvrir'), 'emplacement libre : « Installer », cachette existante : « Ouvrir » (pas de double installation)');
    check(await page.$eval('#pkList .slot[data-slot="seat_p"]', (b) => b.disabled), 'siège occupé : emplacement désactivé');
    await page.click('#pkList .slot[data-slot="wheel_fl"]');
    let post = await page.evaluate(() => window.__posts.find((p) => p.name === 'pick'));
    check(post && post.data.slot === 'wheel_fl', 'clic : emplacement choisi envoyé au client');

    await page.reload();
    await page.evaluate(() => window.postMessage({ action: 'slots', role: 'police', slots: [{ id: 'trunk', label: 'Coffre (garniture)', type: 'trunk' }] }, '*'));
    await page.waitForSelector('#picker:not(.hidden)');
    const pol = await page.$eval('#pkList', (l) => l.textContent);
    check(!/kg|Cachette|Libre/.test(pol), 'police : la liste ne révèle ni cachette ni capacité');
    await page.keyboard.press('Escape');
    post = await page.evaluate(() => window.__posts.find((p) => p.name === 'close'));
    check(!!post, 'Échap ferme le choix');

    const results = {};
    for (const game of ['door', 'trunk', 'wheel', 'seat', 'saddle']) {
        console.log(`\n[Mini-jeu ${game} : joueur automatique parfait]`);
        await page.reload();
        await page.evaluate(BOT);
        await page.evaluate((g) => window.postMessage({ action: 'game', game: g, mode: 'install', label: 'Test ' + g, params: { difficulty: 3, length: 1, maxErrors: 4, timeLimit: 240, seed: 12345 } }, '*'), game);
        await page.waitForTimeout(6000);
        await page.screenshot({ path: path.join(SHOTS, `${game}_1.png`) });
        const shots = [];
        const t0 = Date.now();
        let idx = 0;
        while (Date.now() - t0 < 230000) {
            const st = await page.evaluate(() => { const r = window.__cach.run; return r ? { idx: r.idx, intro: r.intro } : null; });
            const res = await page.evaluate(() => window.__posts.find((p) => p.name === 'result'));
            if (res) break;
            if (st && st.idx > idx && st.intro < 0.9 && st.intro > 0.2) { idx = st.idx; }
            if (st && st.idx === idx && idx > 0 && !shots.includes(idx) && st.intro <= 0) { await page.waitForTimeout(2500); await page.screenshot({ path: path.join(SHOTS, `${game}_${idx + 1}.png`) }); shots.push(idx); }
            await page.waitForTimeout(500);
        }
        const res = await page.evaluate(() => window.__posts.find((p) => p.name === 'result'));
        results[game] = res && res.data;
        check(res && res.data.success === true, `${game} : terminé avec succès`);
        if (res) console.log(`       durée ${(res.data.elapsed / 1000).toFixed(1)} s, ${res.data.errors} erreur(s)`);
        check(res && res.data.elapsed >= 40000, `${game} : durée plancher ≥ 40 s (minimum serveur)`);
        const progress = await page.evaluate(() => window.__posts.filter((p) => p.name === 'progress').length);
        check(res && progress === res.data.errors, `${game} : chaque erreur est signalée au serveur pendant la partie`);
    }

    console.log('\n[Échec : trop d\'erreurs]');
    await page.reload();
    await page.evaluate(BOT);
    await page.evaluate(() => { window.__bot.sloppy = true; });
    await page.evaluate(() => window.postMessage({ action: 'game', game: 'saddle', mode: 'install', label: 'Selle', params: { difficulty: 3, length: 1, maxErrors: 3, timeLimit: 240, seed: 7 } }, '*'));
    let r = await waitResult(page, 30000);
    check(r.data.success === false && r.data.errors === 4, 'au-delà des erreurs tolérées (3) : échec, 4 erreurs renvoyées');

    console.log('\n[Échec : temps écoulé]');
    await page.reload();
    await page.evaluate(() => window.postMessage({ action: 'game', game: 'door', mode: 'install', label: 'Portière', params: { difficulty: 3, length: 1, maxErrors: 4, timeLimit: 30, seed: 7 } }, '*'));
    r = await waitResult(page, 40000);
    check(r.data.success === false, 'limite de temps atteinte : échec');

    console.log('\n[Annulation]');
    await page.reload();
    await page.evaluate(() => window.postMessage({ action: 'game', game: 'wheel', mode: 'search', label: 'Roue', params: { difficulty: 3, length: 1, maxErrors: 4, timeLimit: 180, seed: 9 } }, '*'));
    await page.waitForTimeout(1800);
    await page.mouse.click(640, 420);   // un clic dans le noir de la lampe → pas d'erreur à l'étape 1 (couple) : rien
    await page.keyboard.press('Escape');
    r = await waitResult(page, 5000);
    check(r.data.cancelled === true, 'Échap : annulation propre renvoyée');
    check(await page.$eval('#game', (g) => g.classList.contains('hidden')), 'interface fermée après annulation');

    console.log('\n[Vraies entrées souris : étape 1 de la portière]');
    await page.reload();
    await page.evaluate(() => window.postMessage({ action: 'game', game: 'door', mode: 'open', label: 'Portière', params: { difficulty: 3, length: 1, maxErrors: 4, timeLimit: 180, seed: 3 } }, '*'));
    await page.waitForTimeout(1600);
    const box = await page.$eval('#cv', (c) => { const b = c.getBoundingClientRect(); return { x: b.x, y: b.y, w: b.width }; });
    await page.mouse.click(box.x + 100, box.y + 100);
    const e1 = await page.evaluate(() => window.__cach.run.errors + window.__cach.run.phases[0].S.hits);
    check(e1 === 1, 'un vrai clic souris est pris en compte (frappe réussie ou ripée)');

    console.log('\n[Console]');
    check(errors.length === 0, 'aucune erreur JavaScript' + (errors.length ? ' : ' + errors.join(' | ') : ''));
    await browser.close();
    console.log(`\n${passes} ok, ${fails} échec(s)`);
    fs.writeFileSync(path.join(SHOTS, 'durees.json'), JSON.stringify(results, null, 2));
    process.exit(fails ? 1 : 0);
})();
