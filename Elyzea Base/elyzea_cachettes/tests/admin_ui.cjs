// Test du menu staff : onglet « Cachettes véhicules » (admin_menu + elyzea_cachettes), Chromium headless.
// node tests/admin_ui.cjs   (depuis elyzea_cachettes/)
const { chromium } = require('playwright');
const path = require('path');
const out = path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0, oks = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (c) oks++; else fails++; };

const caps = { small: { door: 5, trunk: 5, wheel: 5, seat: 5 }, medium: { door: 10, trunk: 15, wheel: 10, seat: 10 }, large: { door: 15, trunk: 30, wheel: 15, seat: 15 }, moto: { saddle: 5 } };
const LABELS = { small: 'Petits véhicules', medium: 'Véhicules moyens', large: 'SUV et grands véhicules', moto: 'Motos et scooters' };
const cachettes = {
    available: true, tool: 'tournevis', installed: 3, minSeconds: 40,
    categories: Object.keys(caps).map((id) => ({ id, label: LABELS[id], caps: caps[id], defCaps: caps[id] })),
    classes: [{ class: 0, label: 'Compactes', category: 'small', def: 'small' }, { class: 2, label: 'SUV', category: 'large', def: 'large' }, { class: 18, label: 'Urgences', category: 'none', def: 'none' }],
    models: [],
    games: ['door', 'trunk', 'wheel', 'seat', 'saddle'].map((t) => ({ type: t, label: t, game: 'Mini-jeu ' + t, enabled: true, difficulty: 3, length: 1, maxErrors: 4, timeLimit: 180 })),
    access: { requireKeys: true, policeNeedsTool: true, policeInspectPerm: 'veh_inspect', policeOpenPerm: 'veh_cachettes' },
    inspect: { duration: 12000, light: 'Une petite anomalie semble présente au niveau %s.', high: 'Il semblerait qu\'une intervention ait été effectuée au niveau %s.', none: 'L\'inspection n\'a révélé aucun élément suspect.' },
    blacklist: [],
    lookup: { plate: 'ELY 42', vehicleId: 7, model: 'baller', owner: 'CRIM', list: [
        { slot: 'door_fr', label: 'Portière avant droite', state: 1, attempts: 1, suspicion: 1, capacity: 15, discovered: false, items: 4, busy: false },
        { slot: 'trunk', label: 'Coffre (garniture)', state: 1, attempts: 0, suspicion: 0, capacity: 30, discovered: true, items: 0, busy: false },
        { slot: 'seat_d', label: 'Siège conducteur', state: 0, attempts: 2, suspicion: 0, capacity: 0, discovered: false, items: 0, busy: false },
    ] },
};

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1500, height: 1100 } });
    const posts = [];
    page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
    await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
    await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', '..', 'admin_menu', 'html', 'index.html'));
    await page.evaluate((cachettes) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: { me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms: { cachettes_manage: true }, onDuty: true, duty: true },
            players: [], keys: [], jobs: [], cachettes, config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] } } }, '*');
    }, cachettes);
    await page.waitForTimeout(300);
    const inCat = await page.evaluate(() => typeof catOf === 'function' && catOf('cachettes').id);
    check(inCat === 'illegal', 'onglet rangé dans la catégorie « Illégal »');
    await page.evaluate(() => { tab = 'cachettes'; render(); }); await page.waitForTimeout(200);
    const txt = await page.textContent('#content');
    check(txt.includes('Capacité de chaque emplacement') && txt.includes('Catégorie par classe') && txt.includes('Emplacements et mini-jeux') && txt.includes('Police et accès') && txt.includes('Objets interdits'),
        'sections : capacités, catégories, mini-jeux, police, objets interdits');
    check(txt.includes('Portière avant droite') && txt.includes('Légère') && txt.includes('découverte par la police') && txt.includes('Installation non terminée'), 'recherche par plaque : suspicion, découverte, installation en cours');
    check(await page.$eval('[data-caa="delete"][data-slot="door_fr"]', (b) => b.disabled), 'cachette pleine : bouton « Supprimer » désactivé');
    await page.screenshot({ path: path.join(out, 'admin_cachettes.png'), fullPage: true });

    await page.fill('[data-cap="categories.2.caps.trunk"]', '40');
    await page.fill('[data-cap="games.0.difficulty"]', '5');
    await page.selectOption('[data-cap="classes.0.category"]', 'medium');
    await page.click('[data-cap="access.policeNeedsTool"]');
    await page.fill('[data-cap="blacklistText"]', 'WEAPON_RPG, bank_drill');
    await page.click('[data-caa="model_add"]');
    await page.fill('[data-cap="models.0.model"]', 'panto');
    await page.selectOption('[data-cap="models.0.category"]', 'small');
    await page.click('[data-caa="save"]'); await page.waitForTimeout(150);
    const save = posts.filter((p) => p.ep === 'action' && p.body.name === 'cachettes').pop();
    const d = save && save.body.data.data;
    check(save && save.body.data.name === 'save', 'enregistrement envoyé');
    check(d && d.categories[2].caps.trunk === 40 && d.games[0].difficulty === 5 && d.classes[0].category === 'medium', 'valeurs envoyées : coffre SUV 40 kg, portière difficulté 5, compactes → moyen');
    check(d && d.access.policeNeedsTool === false && d.blacklist.join('|') === 'WEAPON_RPG|bank_drill' && d.models[0].model === 'panto' && d.models[0].category === 'small', 'police sans tournevis, objets interdits, exception de modèle');

    await page.fill('#caPlate', 'ELY 42');
    await page.click('[data-caa="lookup"]'); await page.waitForTimeout(100);
    const look = posts.filter((p) => p.ep === 'action' && p.body.name === 'cachettes').pop();
    check(look.body.data.name === 'lookup' && look.body.data.data.plate === 'ELY 42', 'recherche par plaque envoyée');
    await browser.close();
    console.log(`\nCachettes (menu staff) : ${oks} ok, ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
