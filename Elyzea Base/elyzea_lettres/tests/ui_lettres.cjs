// Test de l'interface (rédaction, pagination, lecture, enveloppe) dans Chromium.
//   node tests/ui_lettres.cjs [dossier_captures]       (Playwright requis : npm i playwright)
// Les appels au jeu (https://elyzea_lettres/...) sont interceptés et vérifiés.
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const shots = process.argv[2];
const URL = 'file://' + path.resolve(__dirname, '..', 'html', 'index.html');
let fails = 0, passes = 0;
const check = (c, l) => { if (c) { passes++; console.log('  ok   ', l); } else { fails++; console.log('  ÉCHEC', l); } };
const section = (t) => console.log(`\n[${t}]`);
const FONTS = [{ id: 'elegante', label: 'Élégante' }, { id: 'naturelle', label: 'Naturelle' }, { id: 'arrondie', label: 'Arrondie' }];
const PAPERS = [{ id: 'creme', label: 'Crème' }, { id: 'ligne', label: 'Blanc ligné' }, { id: 'ancien', label: 'Vieilli' }];
const writeMsg = (extra = {}) => ({ action: 'write', data: { token: 't', limits: { maxChars: 3000, maxPages: 4, recipient: 60, signature: 60 }, fonts: FONTS, papers: PAPERS,
  date: 'Los Santos, le 15 novembre 2026', defaultFont: 'elegante', consume: 'letter', ...extra } });
const LONG = Array.from({ length: 10 }, (_, i) => `Paragraphe ${i + 1} : voilà bien des semaines que je n'ai pas eu de tes nouvelles, et je m'inquiète un peu. Les journées à Los Santos s'étirent, l'été n'en finit plus, et le café du coin de la rue n'a plus le même goût sans toi.`).join('\n\n');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const posts = [];
  await page.route('https://elyzea_lettres/**', async (route) => {
    const name = route.request().url().split('/').pop();
    let body = {}; try { body = JSON.parse(route.request().postData() || '{}'); } catch (e) {}
    posts.push({ name, body });
    await route.fulfill({ status: 200, body: '"ok"' });
  });
  await page.goto(URL);
  const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
  const lastPost = (n) => [...posts].reverse().find((p) => p.name === n);
  const sheetText = () => page.$eval('#sheet .p-body', (e) => [...e.querySelectorAll('.para')].map((p) => [...p.querySelectorAll('[data-o]')].map((s) => s.textContent).join('')).join('\n'));
  const snap = async (n) => { if (shots) await page.screenshot({ path: path.join(shots, n) }); };
  const state = () => page.evaluate(() => ({ pages: document.querySelector('#pageinfo').textContent, finish: document.querySelector('#btn-finish').disabled }));

  section('Ouverture et écriture en direct');
  await send(writeMsg());
  await page.waitForTimeout(400);
  check(await page.isVisible('#sheet'), 'la feuille s\'affiche');
  check(await page.evaluate(() => document.activeElement.id) === 'in-recipient', 'le curseur commence sur le destinataire');
  await page.keyboard.type('Élodie Faure');
  check((await page.textContent('#sheet .p-to')).includes('Élodie Faure'), 'destinataire écrit sur la feuille au fur et à mesure');
  await page.keyboard.press('Enter');
  await page.keyboard.type('Chère Élo');
  check((await sheetText()) === 'Chère Élo', 'les lettres apparaissent sur la feuille pendant la frappe');
  check(await page.$('#sheet .p-body .caret') !== null, 'curseur d\'encre visible dans la lettre');
  await page.keyboard.type("die,\n\nÇa fait longtemps ! « Où es-tu ? » L'été… naïf, cœur, Œdipe, à, è, ù, ê, ï — 100 % d'accord.\nLigne suivante.");
  const txt = await sheetText();
  check(txt.includes('« Où es-tu ? »') && txt.includes('cœur, Œdipe') && txt.includes('100 %'), 'accents, guillemets, apostrophes, ligatures, ponctuation');
  check(txt.split('\n').length === 4 && txt.split('\n')[1] === '', 'retours à la ligne et ligne vide respectés');

  section('Correction du texte');
  for (let i = 0; i < 15; i++) await page.keyboard.press('ArrowLeft');      // avant « Ligne suivante. »
  await page.keyboard.type('Nouvelle phrase. ');
  check((await sheetText()).endsWith('Nouvelle phrase. Ligne suivante.'), 'insertion au milieu (flèches)');
  for (let i = 0; i < 17; i++) await page.keyboard.press('Backspace');
  check((await sheetText()).endsWith('accord.\nLigne suivante.'), 'suppression (retour arrière)');
  // clic sur un mot de la feuille : le stylo s'y place
  const box = await page.$eval('#sheet .p-body .para:first-child span[data-o]', (e) => { const r = e.getBoundingClientRect(); return { x: r.left + 3, y: r.top + r.height / 2 }; });
  await page.mouse.click(box.x, box.y);
  await page.keyboard.type('Ma ');
  check((await sheetText()).startsWith('Ma Chère Élodie,'), 'clic sur la feuille : le curseur se place à l\'endroit cliqué');
  await page.keyboard.press('Control+a'); await page.waitForTimeout(50);
  check(await page.$('#sheet mark') !== null, 'sélection affichée sur la feuille');
  await page.keyboard.press('ArrowRight');
  await page.keyboard.press('Tab');
  await page.keyboard.type('Ton ami, Hugo');
  check((await page.textContent('#sheet .p-sign')).includes('Ton ami, Hugo'), 'signature écrite en bas de lettre');
  await snap('01_redaction.png');

  section('Styles d\'écriture et papiers');
  for (const f of ['naturelle', 'arrondie', 'elegante']) {
    await page.click(`[data-font="${f}"]`);
    check(await page.$eval('#sheet', (e, f) => e.classList.contains('font-' + f), f), `style « ${f} » appliqué`);
    if (f !== 'elegante') await snap(`02_style_${f}.png`);
  }
  for (const p of ['ligne', 'ancien', 'creme']) {
    await page.click(`[data-paper="${p}"]`);
    check(await page.$eval('#sheet', (e, p) => e.classList.contains('paper-' + p), p), `papier « ${p} » appliqué`);
    if (p !== 'creme') await snap(`03_papier_${p}.png`);
  }
  check(await page.evaluate(() => document.activeElement.id) === 'in-signature', 'le clavier reste dans le texte après un changement de style');

  section('Pagination');
  await page.click('#sheet .p-body');
  await page.keyboard.press('Control+a');
  await page.keyboard.insertText(LONG);
  await page.waitForTimeout(100);
  const st = await state();
  const pages = await page.evaluate(() => {
    const s = document.querySelector('#pageinfo').textContent.match(/\/ (\d+)/); return s ? Number(s[1]) : 0;
  });
  check(pages >= 2 && pages <= 4, `lettre longue (${LONG.length} caractères) répartie sur ${pages} pages (${st.pages})`);
  // aucune page ne déborde, et toutes les pages mises bout à bout redonnent le texte exact
  const all = await page.evaluate(async (n) => {
    const out = [];
    for (let i = 0; i < n; i++) {
      document.querySelector('#prev').disabled || 0;
      out.push(1);
    }
    return out.length;
  }, pages);
  // aller à la première page
  for (let i = 0; i < pages; i++) await page.click('#prev').catch(() => {});
  let rebuilt = '', overflow = false, signLast = false, headFirst = false;
  for (let i = 0; i < pages; i++) {
    const info = await page.evaluate(() => {
      const b = document.querySelector('#sheet .p-body'), inner = document.querySelector('#sheet .page-inner');
      return { a: Number(b.dataset.a), b: Number(b.dataset.b), over: b.scrollHeight > b.clientHeight + 1 || inner.scrollHeight > inner.clientHeight + 1,
        sign: !!document.querySelector('#sheet .p-sign'), head: !!document.querySelector('#sheet .p-head') };
    });
    const t = await sheetText();
    rebuilt += (i ? '\u0000' : '') + t;
    if (info.over) overflow = true;
    if (i === 0) headFirst = info.head;
    if (i === pages - 1) signLast = info.sign;
    if (i === 0 && pages > 1 && info.sign) signLast = 'tôt';
    if (i < pages - 1) await page.click('#next');
  }
  check(!overflow, 'aucune page ne déborde');
  check(headFirst && signLast === true, 'date et destinataire en page 1, signature sur la dernière page');
  const joined = rebuilt.split('\u0000').join('');
  check(joined.replace(/\s/g, '') === LONG.replace(/\s/g, ''), 'les pages mises bout à bout redonnent tout le texte, sans perte ni doublon');
  await snap('04_page_suivante.png');
  // le curseur suit l'écriture : taper ramène à la page du curseur
  await page.click('#prev');
  await page.keyboard.type('!');
  const pi = await page.textContent('#pageinfo');
  check(!pi.startsWith('Page 1 /') && await page.$('#sheet .caret') !== null && (await sheetText()).endsWith('!'), `en tapant, la feuille revient à la page du curseur (${pi})`);
  await page.keyboard.press('Backspace');

  section('Limites');
  const tooLong = (LONG + '\n\n').repeat(3).slice(0, 2990);
  await page.keyboard.press('Control+a');
  await page.keyboard.insertText(tooLong.replace(/ /g, '\n').slice(0, 1500));
  await page.waitForTimeout(100);
  const s2 = await state();
  check(s2.finish === true && /maximum/.test(s2.pages), `trop de pages : « ${s2.pages} », bouton Terminer bloqué`);
  await page.keyboard.press('Control+a');
  await page.keyboard.insertText('x'.repeat(3500));
  check((await page.$eval('#in-body', (e) => e.value.length)) === 3000, 'limite de 3 000 caractères appliquée à la saisie');
  await page.keyboard.press('Control+a');
  await page.keyboard.insertText(LONG.slice(0, 500));

  section('Aperçu');
  await page.click('#btn-preview');
  check(await page.$('#sheet .caret') === null && await page.$('#sheet .ph') === null, 'aperçu : ni curseur ni texte indicatif');
  await snap('05_apercu.png');
  await page.click('#btn-preview');
  await page.keyboard.type(' Fin.');
  check((await sheetText()).endsWith('Fin.'), 'retour à l\'écriture depuis l\'aperçu');

  section('Brouillon automatique');
  await page.waitForTimeout(4300);
  const d = lastPost('draft');
  check(d && d.body.body.endsWith('Fin.') && d.body.recipient === 'Élodie Faure', 'brouillon envoyé au serveur pendant l\'écriture');

  section('Annuler');
  await page.keyboard.press('Escape');
  check(await page.isVisible('#modal'), 'confirmation avant de quitter une lettre non terminée');
  check((await page.textContent('#modal')).includes('pas'), 'le message précise que la feuille n\'est pas utilisée');
  await snap('06_quitter.png');
  await page.click('#modal-btns >> text=Continuer d\'écrire');
  check(!(await page.isVisible('#modal')) && (await page.evaluate(() => document.activeElement.id)) === 'in-body', '« Continuer d\'écrire » ramène dans la lettre, texte intact');
  await page.keyboard.press('Escape');
  await page.click('#modal-btns >> text=Garder le brouillon');
  await page.waitForTimeout(200);
  const c = lastPost('cancel');
  check(c && c.body.keep === true && c.body.draft.body.endsWith('Fin.'), 'annulation avec brouillon gardé');
  check(!(await page.isVisible('#sheet')), 'interface fermée');

  section('Reprise du brouillon et fin de la lettre');
  await send(writeMsg({ draft: { recipient: 'Élodie Faure', body: 'Chère Élodie,\n\nÀ bientôt.', signature: 'Hugo', font: 'naturelle', paper: 'ligne' } }));
  await page.waitForTimeout(400);
  const dt = await sheetText(), dc = await page.$eval('#sheet', (e) => e.className);
  check(dt === 'Chère Élodie,\n\nÀ bientôt.' && dc.includes('font-naturelle') && dc.includes('paper-ligne'), `brouillon retrouvé (texte, style, papier) [${JSON.stringify(dt)} ${dc}]`);
  await page.click('#btn-finish');
  check((await page.textContent('#modal')).includes('ne pourra plus être modifiée'), 'confirmation : la lettre ne sera plus modifiable');
  await snap('07_terminer.png');
  await page.click('#modal-btns >> text=Terminer la lettre');
  await page.waitForTimeout(200);
  const f = lastPost('finish');
  check(f && f.body.body === 'Chère Élodie,\n\nÀ bientôt.' && f.body.font === 'naturelle' && f.body.paper === 'ligne' && f.body.pages === 1 && f.body.recipient === 'Élodie Faure',
    'contenu envoyé au serveur (texte, destinataire, style, papier, pages)');
  check(await page.$eval('#btn-finish', (e) => e.disabled), 'pas de double envoi pendant l\'attente');
  await send({ action: 'finished', ok: false, message: 'Vous n\'avez plus de feuille de papier.' });
  await page.waitForTimeout(100);
  check((await page.textContent('#toast')).includes('feuille') && (await sheetText()) === 'Chère Élodie,\n\nÀ bientôt.', 'refus du serveur : message, texte conservé');
  await page.click('#btn-finish'); await page.click('#modal-btns >> text=Terminer la lettre');
  await send({ action: 'finished', ok: true, message: 'ok' });
  await page.waitForTimeout(200);
  check(await page.$eval('#sheet-wrap', (e) => e.classList.contains('folding')), 'lettre pliée à la fin');
  await send({ action: 'hide' });

  section('Lecture (même mise en page)');
  // la pagination à la lecture doit être identique à celle de la rédaction
  await send(writeMsg({ draft: { recipient: 'Élodie Faure', body: LONG, signature: 'Hugo', font: 'arrondie', paper: 'ancien' } }));
  await page.waitForTimeout(400);
  const writerPages = await page.evaluate(() => Number(document.querySelector('#pageinfo').textContent.match(/\/ (\d+)/)[1]));
  await send({ action: 'hide' });
  await send({ action: 'read', letter: { id: 'LTEST', recipient: 'Élodie Faure', body: LONG, signature: 'Hugo', font: 'arrondie', paper: 'ancien', date: 'Los Santos, le 15 novembre 2026', pages: writerPages },
    opts: { canEnvelope: true } });
  await page.waitForTimeout(400);
  const readPages = await page.evaluate(() => Number((document.querySelector('#read-info').textContent.match(/\/ (\d+)/) || [0, 1])[1]));
  check(readPages === writerPages, `même nombre de pages à la lecture (${readPages}) qu'à la rédaction (${writerPages})`);
  check(await page.$('#sheet .caret') === null && !(await page.isVisible('#bar-write')), 'lecture seule : pas de curseur, pas d\'outils d\'écriture');
  check((await page.textContent('#sheet .p-date')).includes('15 novembre 2026') && (await page.textContent('#sheet .p-to')).includes('Élodie Faure'), 'date et destinataire affichés');
  await snap('08_lecture.png');
  await page.keyboard.press('ArrowRight');
  check((await page.textContent('#read-info')).startsWith('Page 2'), 'flèche droite : page suivante');
  await page.keyboard.press('ArrowLeft');
  check((await page.textContent('#read-info')).startsWith('Page 1'), 'flèche gauche : page précédente');
  check(await page.isVisible('#btn-envelope'), 'bouton « Mettre sous enveloppe » (enveloppe vide sur soi)');
  await page.click('#btn-envelope');
  await page.waitForTimeout(200);
  check(lastPost('putInEnvelope'), 'demande de mise sous enveloppe envoyée');
  await page.keyboard.press('Escape'); await page.waitForTimeout(200);
  check(lastPost('close') && !(await page.isVisible('#sheet')), 'Échap ferme la lettre');

  section('Enveloppe');
  await send({ action: 'envelope', envelope: { recipient: 'Élodie Faure', font: 'elegante', opened: false } });
  await page.waitForTimeout(400);
  check((await page.textContent('#env-name')) === 'Élodie Faure' && await page.isVisible('#env-seal'), 'destinataire écrit sur l\'enveloppe, cachet de cire');
  await snap('09_enveloppe.png');
  await page.click('#btn-open-env');
  await page.waitForTimeout(700);
  check(lastPost('openEnvelope'), 'ouverture de l\'enveloppe demandée au serveur');
  await send({ action: 'read', letter: { id: 'LTEST', recipient: 'Élodie Faure', body: 'Coucou', signature: 'Hugo', font: 'elegante', paper: 'creme', date: 'Le 1er mai 2026', pages: 1 }, opts: { fromEnvelope: true } });
  await page.waitForTimeout(200);
  check(await page.isVisible('#btn-takeout') && !(await page.isVisible('#btn-envelope')), 'lettre lue depuis l\'enveloppe : « Sortir la lettre »');
  await send({ action: 'hide' });

  section('Calibrage (lignes par page)');
  for (const font of ['elegante', 'naturelle', 'arrondie']) {
    const r = await page.evaluate((font) => {
      const L = LetterLayout;
      const one = 'a\n'.repeat(80).slice(0, -1);
      const pg = L.paginate({ recipient: 'x', body: one, signature: 'x', font, paper: 'creme' }, 'date');
      const wide = L.paginate({ recipient: '', body: 'i'.repeat(5000), signature: '', font, paper: 'creme' }, 'date');
      return { firstLines: pg[0].b === 0 ? 0 : one.slice(0, pg[0].b).split('\n').length, secondLines: pg[1] ? one.slice(pg[1].a, pg[1].b).split('\n').length : 0, wide: wide.length };
    }, font);
    console.log(`        ${font} : ${r.firstLines} lignes en page 1, ${r.secondLines} lignes en page pleine`);
    check(r.secondLines <= 22, `${font} : une page pleine ne dépasse pas 22 lignes (borne serveur Config.Layout)`);
  }

  check(errors.length === 0, 'aucune erreur JavaScript' + (errors.length ? ' : ' + errors.join(' | ') : ''));
  await browser.close();
  console.log(`\n${passes} réussi(s), ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
