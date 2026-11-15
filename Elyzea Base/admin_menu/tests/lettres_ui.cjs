// Test du menu staff : onglet « Lettres » (elyzea_lettres), Chromium headless.
// node tests/lettres_ui.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1500, height: 1100 } });
    const posts = [];
    page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
    await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
    await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    const send = (perms, lettres) => page.evaluate(({ perms, lettres }) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: {
            me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true }, players: [], keys: [], jobs: [], lettres,
            config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] },
        } }, '*');
    }, { perms, lettres });
    const LET = { available: true,
        settings: { maxChars: 3000, maxPages: 4, consume: 'letter', envelopes: true, animation: true, defaultFont: 'elegante',
            fonts: { elegante: true, naturelle: true, arrondie: true }, papers: { creme: true, ligne: true, ancien: true } },
        limits: { maxChars: [200, 10000], maxPages: [1, 10] },
        fonts: [{ id: 'elegante', label: 'Élégante' }, { id: 'naturelle', label: 'Naturelle' }, { id: 'arrondie', label: 'Arrondie' }],
        papers: [{ id: 'creme', label: 'Crème' }, { id: 'ligne', label: 'Blanc ligné' }, { id: 'ancien', label: 'Vieilli' }],
        items: { paper: 'feuille_papier', pen: 'stylo_bille', letter: 'lettre', envelope: 'enveloppe', sealed: 'enveloppe_lettre' },
        stats: { total: 12, today: 3, week: 9 },
        recent: [{ id: 'L6A1B2C0F3E1', created: '15/11/2026 14:03', author_name: 'Hugo Martin', author_cid: 'CIT001', recipient: 'Élodie Faure', pages: 2, font: 'elegante' }] };

    await send({}, undefined);
    await page.waitForTimeout(300);
    check(!(await page.evaluate(() => TABS.find((t) => t.id === 'lettres').show())), 'sans la permission « lettres_manage » : onglet caché');
    await send({ lettres_manage: true }, LET);
    await page.waitForTimeout(300);
    check(await page.evaluate(() => TABS.find((t) => t.id === 'lettres').show()), 'avec la permission : onglet visible');
    await page.evaluate(() => { tab = 'lettres'; render(); });
    await page.waitForTimeout(200);
    const txt = await page.textContent('#content');
    check(txt.includes('Lettres écrites') && txt.includes('12') && txt.includes('Élodie Faure') && txt.includes('Hugo Martin'), 'statistiques et dernières lettres');
    check(!txt.includes('undefined'), 'aucun « undefined » affiché');
    await page.screenshot({ path: path.join(out, 'lettres_admin.png'), fullPage: true });
    const last = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'lettres').pop();
    await page.fill('[data-lnum="maxChars"]', '5000');
    await page.fill('[data-lnum="maxPages"]', '6');
    await page.selectOption('[data-lsel="consume"]', 'page');
    await page.click('[data-ltg="font:arrondie"]');
    await page.click('[data-ltg="paper:ancien"]');
    await page.click('[data-ltg="envelopes"]');
    await page.click('[data-ltg="font:naturelle"]', { button: 'right' });
    await page.click('[data-lact="save"]');
    await page.waitForTimeout(100);
    const d = last() && last().body.data;
    check(d && d.name === 'save' && d.data.maxChars === 5000 && d.data.maxPages === 6 && d.data.consume === 'page', 'nombres et consommation envoyés');
    check(d && d.data.fonts.arrondie === false && d.data.papers.ancien === false && d.data.envelopes === false && d.data.defaultFont === 'naturelle', 'styles, papiers, enveloppes, style par défaut envoyés');
    await browser.close();
    console.log(fails ? `\n${fails} échec(s)` : '\nTout est bon.');
    process.exit(fails ? 1 : 0);
})();
