// Test de la PAGE D'IMPORT du logo (navigateur de l'ordinateur) : serveur et hébergeur imités, Chromium headless
// NODE_PATH=$(npm root -g) node tests/ui_logo_page.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const out = process.argv[2] || path.join(__dirname, 'shots');
fs.mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
// PNG 800 × 400 (rectangle) fabriqué à la volée
const { execSync } = require('child_process');
const img = path.join(out, 'logo_test.png');
execSync(`python3 -c "from PIL import Image; Image.new('RGB',(800,400),(124,108,255)).save('${img}')"`);
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 900, height: 820 }, deviceScaleFactor: 1 });
  const errs = []; p.on('pageerror', (e) => errs.push(e.message));
  const hits = []; let uploaded = null;
  await p.route('http://serveur.test/**', async (r) => {
    const u = new URL(r.request().url());
    if (u.pathname === '/elyzea_entreprises/logo') return r.fulfill({ contentType: 'text/html; charset=utf-8', body: fs.readFileSync(path.join(__dirname, '..', 'web', 'logo.html'), 'utf8') });
    const body = JSON.parse(r.request().postData() || '{}');
    hits.push({ path: u.pathname, body });
    if (body.code !== 'K7P2QD') return r.fulfill({ status: 403, contentType: 'application/json', body: JSON.stringify({ ok: false, error: 'Code invalide ou expiré.' }) });
    if (u.pathname.endsWith('/logo/check')) return r.fulfill({ contentType: 'application/json', body: JSON.stringify({ ok: true, maxMb: 5 }) });
    if (u.pathname.endsWith('/logo/start')) return r.fulfill({ contentType: 'application/json', body: JSON.stringify({ ok: true, uploadUrl: 'https://api.fivemanage.test/upload?t=1' }) });
    if (u.pathname.endsWith('/logo/finish')) return r.fulfill({ contentType: 'application/json', body: JSON.stringify({ ok: true }) });
    return r.fulfill({ status: 404, body: '' });
  });
  await p.route('https://api.fivemanage.test/**', async (r) => { uploaded = r.request().postDataBuffer(); r.fulfill({ contentType: 'application/json', body: JSON.stringify({ data: { url: 'https://r2.fivemanage.test/logo.png' } }) }); });
  await p.goto('http://serveur.test/elyzea_entreprises/logo?code=k7p2qd');
  await p.waitForTimeout(500);
  check(await p.inputValue('#code') === 'K7P2QD', 'code repris du lien (en majuscules)');
  check((await p.textContent('#msg')).includes('Code valable'), 'code vérifié auprès du serveur');
  check(hits[0] && hits[0].path === '/elyzea_entreprises/logo/check', 'adresse de l\'API relative à la page');
  check(await p.isDisabled('#send'), 'envoi impossible sans image');
  await p.setInputFiles('#file', img); await p.waitForTimeout(600);
  check(!(await p.isDisabled('#send')) && await p.isVisible('#preview'), 'image choisie : aperçu et bouton actif');
  const dims = await p.evaluate(() => new Promise((res) => { const i = new Image(); i.onload = () => res([i.width, i.height]); i.src = getComputedStyle(document.querySelector('#preview')).backgroundImage.slice(5, -2); }));
  check(dims[0] === 512 && dims[1] === 512, `recadrée en carré 512 × 512 (${dims})`);
  await p.screenshot({ path: path.join(out, 'logo_page_1.png') });
  await p.click('#send'); await p.waitForTimeout(800);
  const start = hits.find((h) => h.path.endsWith('/logo/start'));
  check(start && start.body.type === 'image/png' && start.body.size > 0 && start.body.size < 50000, 'taille et type envoyés au serveur avant l\'envoi');
  check(uploaded && uploaded.length > 0, 'image envoyée directement à l\'hébergeur (pas par le serveur FiveM)');
  const fin = hits.find((h) => h.path.endsWith('/logo/finish'));
  check(fin && fin.body.url === 'https://r2.fivemanage.test/logo.png', 'lien de l\'image renvoyé au serveur');
  check((await p.textContent('#msg')).includes('Logo envoyé'), 'message de réussite');
  await p.screenshot({ path: path.join(out, 'logo_page_2.png') });
  await p.fill('#code', 'ZZZZZZ'); await p.click('#send'); await p.waitForTimeout(500);
  check((await p.textContent('#msg')).includes('Code invalide'), 'mauvais code : message d\'erreur du serveur');
  check(errs.length === 0, `aucune erreur JavaScript (${errs.join(' | ')})`);
  await b.close();
  console.log(fails ? `\n${fails} ÉCHEC(S)` : '\nTOUT EST OK');
  process.exit(fails ? 1 : 0);
})();
